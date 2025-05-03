/**
 * Batch Apex implementation for parsing OpenAPI annotations from Apex classes
 * Designed to handle large codebases with proper governor limit management
 */
public class OpenAPIParserBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    // Stateful variables to maintain information between batches
    private Map<String, Object> combinedSpec;
    private Map<String, Object> combinedPaths;
    private String combinedTitle = 'Salesforce REST API';
    private String combinedDescription = 'Combined REST API documentation';
    private String combinedVersion = '1.0.0';
    private String namespace;
    // Keep a stateful copy of schemas to persist between batch transactions
    private Map<String, Map<String, Object>> batchSchemas = new Map<String, Map<String, Object>>();
    
    /**
     * Constructor for parsing all classes in the default namespace
     */
    public OpenAPIParserBatch() {
        this(null);
    }
    
    /**
     * Constructor for parsing classes in a specific namespace
     * @param namespace The namespace to parse (null for default namespace)
     */
    public OpenAPIParserBatch(String namespace) {
        this.namespace = namespace;
        this.combinedSpec = new Map<String, Object>();
        this.combinedPaths = new Map<String, Object>();
        this.batchSchemas = new Map<String, Map<String, Object>>();
        
        // Initialize OpenAPI spec with version
        this.combinedSpec.put('openapi', '3.0.0');
        
        // Reset the schema registry for a fresh start
        OpenAPIParser.resetSchemaRegistry();
    }
    
    /**
     * Start method that queries for classes to process
     * Cannot filter on Body in SOQL - filtering happens in execute method
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name, Body FROM ApexClass';
        if (namespace != null) {
            query += ' WHERE NamespacePrefix = :namespace';
        }
        return Database.getQueryLocator(query);
    }
    
    /**
     * Process each batch of classes
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<ApexClass> allClasses = (List<ApexClass>)scope;
        System.debug('Received batch of ' + allClasses.size() + ' classes');
        
        // Filter classes with OpenAPI annotations in Apex code
        List<ApexClass> classes = new List<ApexClass>();
        Pattern openApiPattern = Pattern.compile('@openapi');
        
        for (ApexClass cls : allClasses) {
            Matcher openApiMatcher = openApiPattern.matcher(cls.Body);
            if (openApiMatcher.find()) {
                classes.add(cls);
            }
        }
        
        System.debug('Filtered down to ' + classes.size() + ' classes with @openapi annotations');
        
        // Track query usage to avoid hitting limits
        Integer queriesRemaining = Limits.getLimitQueries() - Limits.getQueries();
        Integer heapRemaining = Limits.getLimitHeapSize() - Limits.getHeapSize();
        
        for (ApexClass apexClass : classes) {
            // Check remaining governors before processing each class
            if (Limits.getQueries() >= Limits.getLimitQueries() - 5 || 
                Limits.getHeapSize() >= Limits.getLimitHeapSize() * 0.9) {
                System.debug('Approaching governor limits, stopping batch processing early');
                break;
            }
            
            System.debug('Processing class: ' + apexClass.Name);
            
            // Process this class and extract all paths
            Map<String, Object> classSpec = processClass(apexClass);
            
            if (classSpec != null) {
                // Merge info section - only take the first encountered class info
                if (classSpec.containsKey('info')) {
                    Map<String, Object> info = (Map<String, Object>)classSpec.get('info');
                    // Only override the title/description once - from the first class that has it
                    if (info.containsKey('title') && combinedTitle == 'Salesforce REST API') {
                        combinedTitle = (String)info.get('title');
                    }
                    if (info.containsKey('description') && combinedDescription == 'Combined REST API documentation') {
                        combinedDescription = (String)info.get('description');
                    }
                    if (info.containsKey('version')) {
                        combinedVersion = (String)info.get('version');
                    }
                }
                
                // Merge paths in a memory-efficient way
                if (classSpec.containsKey('paths')) {
                    Map<String, Object> paths = (Map<String, Object>)classSpec.get('paths');
                    for (String path : paths.keySet()) {
                        if (!combinedPaths.containsKey(path)) {
                            combinedPaths.put(path, paths.get(path));
                        } else {
                            // Merge HTTP methods for the same path
                            Map<String, Object> existingMethods = (Map<String, Object>)combinedPaths.get(path);
                            Map<String, Object> newMethods = (Map<String, Object>)paths.get(path);
                            for (String method : newMethods.keySet()) {
                                existingMethods.put(method, newMethods.get(method));
                            }
                        }
                    }
                }
            }
        }
        
        // Copy schemas from the registry to our stateful variable after each batch
        Map<String, Map<String, Object>> currentSchemas = OpenAPIParser.getSchemaRegistry();
        if (currentSchemas != null && !currentSchemas.isEmpty()) {
            for (String schemaName : currentSchemas.keySet()) {
                if (!batchSchemas.containsKey(schemaName)) {
                    batchSchemas.put(schemaName, currentSchemas.get(schemaName));
                    System.debug('Saved schema to batch state: ' + schemaName);
                }
            }
            System.debug('Current batch schemas size: ' + batchSchemas.size());
        }
    }
    
    /**
     * Finish method that finalizes and stores the module
     */
    public void finish(Database.BatchableContext bc) {
        // Set the combined info
        combinedSpec.put('info', new Map<String, Object>{
            'title' => combinedTitle,
            'description' => combinedDescription,
            'version' => combinedVersion
        });
        
        // Add servers section with the org's instance URL
        String baseUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest';
        combinedSpec.put('servers', new List<Map<String, Object>>{
            new Map<String, Object>{
                'url' => baseUrl,
                'description' => 'Salesforce Apex REST API'
            }
        });
        
        // Set the combined paths
        combinedSpec.put('paths', combinedPaths);
        
        System.debug('Number of schemas collected during batch execution: ' + batchSchemas.size());
        if (batchSchemas.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'WARNING: No schemas were collected during batch execution!');
        }
        
        // Add components section with schemas from our stateful variable instead of the registry
        Map<String, Object> components = new Map<String, Object>{
            'securitySchemes' => new Map<String, Object>{
                'oauth2' => new Map<String, Object>{
                    'type' => 'oauth2',
                    'flows' => new Map<String, Object>{
                        'authorizationCode' => new Map<String, Object>{
                            'authorizationUrl' => URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/authorize',
                            'tokenUrl' => URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token',
                            'scopes' => new Map<String, String>{
                                'api' => 'Access and manage your data (api)',
                                'refresh_token' => 'Allow access to your data via the Web (refresh_token)',
                                'offline_access' => 'Access your data anytime (offline_access)'
                            }
                        }
                    }
                }
            },
            'schemas' => batchSchemas
        };
        
        // Add the components section to the spec
        combinedSpec.put('components', components);
        
        // Apply security at the root level
        combinedSpec.put('security', new List<Map<String, List<String>>>{
            new Map<String, List<String>>{
                'oauth2' => new List<String>{'api'}
            }
        });
        
        System.debug('Combined OpenAPI specification complete');
        if (combinedSpec.containsKey('components')) {
            Map<String, Object> comps = (Map<String, Object>)combinedSpec.get('components');
            if (comps.containsKey('schemas')) {
                Map<String, Object> schemas = (Map<String, Object>)comps.get('schemas');
                System.debug('Number of schemas in final spec: ' + schemas.size());
                System.debug('Schema names: ' + String.join(new List<String>(schemas.keySet()), ', '));
            } else {
                System.debug('No schemas section in components!');
            }
        } else {
            System.debug('No components section in spec!');
        }
        
        // Store the final spec
        OpenAPIParser.storeAsStaticResource(combinedSpec, 'OPENAPI_SPEC');
    }
    
    /**
     * Process a single class to extract paths and methods
     * @param apexClass The Apex class to process
     * @return Map<String, Object> with paths and class info
     */
    private Map<String, Object> processClass(ApexClass apexClass) {
        String className = apexClass.Name;
        String classBody = apexClass.Body;
        
        Map<String, Object> result = new Map<String, Object>();
        
        // Extract RestResource URL mapping if present
        String baseUrlMapping = OpenAPIParser.extractRestResourceUrlMapping(classBody);
        
        // Extract class-level OpenAPI annotations
        Pattern classPattern = Pattern.compile('/\\*\\*\\s*\\n\\s*\\*\\s*@openapi\\s*\\n\\s*\\*\\s*@title\\s+(.*?)\\n\\s*\\*\\s*@description\\s+(.*?)\\n\\s*\\*\\s*@version\\s+(.*?)\\n\\s*\\*/');
        Matcher classMatcher = classPattern.matcher(classBody);
        
        if (classMatcher.find()) {
            Map<String, Object> info = new Map<String, Object>{
                'title' => classMatcher.group(1).trim(),
                'description' => classMatcher.group(2).trim(),
                'version' => classMatcher.group(3).trim()
            };
            result.put('info', info);
        }
        
        // Extract method-level OpenAPI annotations
        Map<String, Object> paths = new Map<String, Object>();
        
        // Find all method documentation blocks
        Pattern methodPattern = Pattern.compile('/\\*\\*\\s*\\n(\\s*\\*\\s*@[^\\n]*\\n)*\\s*\\*/\\s*\\n*\\s*@(Http\\w+)\\s+.*?\\s+(\\w+)\\s*\\([^)]*\\)');
        Matcher methodMatcher = methodPattern.matcher(classBody);
        
        while (methodMatcher.find()) {
            String methodDoc = methodMatcher.group(0);
            String httpMethod = methodMatcher.group(2).toLowerCase().replace('http', '');
            String methodName = methodMatcher.group(3);
            
            // Extract path parameters
            List<Map<String, Object>> methodParams = OpenAPIParser.extractParameters(methodDoc);
            List<String> pathParams = new List<String>();
            
            for (Map<String, Object> param : methodParams) {
                if (param.get('in') == 'path') {
                    pathParams.add((String)param.get('name'));
                }
            }
            
            // Construct the path
            String path = OpenAPIParser.constructApiPath(baseUrlMapping, httpMethod, methodName, pathParams);
            
            // Parse method info
            Map<String, Object> pathInfo = OpenAPIParser.parseMethod(methodDoc);
            
            if (!paths.containsKey(path)) {
                paths.put(path, new Map<String, Object>());
            }
            ((Map<String, Object>)paths.get(path)).put(httpMethod, pathInfo);
        }
        
        result.put('paths', paths);
        return result;
    }
} 