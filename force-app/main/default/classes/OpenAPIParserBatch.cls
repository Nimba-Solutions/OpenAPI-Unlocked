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
    private Boolean isFinalBatch = false;
    
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
        
        // Initialize OpenAPI spec with version
        this.combinedSpec.put('openapi', '3.0.0');
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
            
            // Calling a refactored method that processes a single class in a memory-efficient way
            Map<String, Object> classSpec = OpenAPIParser.parseClassForBatch(apexClass);
            
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
        
        // Add security schemes
        combinedSpec.put('components', new Map<String, Object>{
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
            }
        });
        
        // Apply security at the root level
        combinedSpec.put('security', new List<Map<String, List<String>>>{
            new Map<String, List<String>>{
                'oauth2' => new List<String>{'api'}
            }
        });
        
        System.debug('Combined OpenAPI specification complete');
        
        // Store the final spec asynchronously to avoid callout limits
        System.enqueueJob(new OpenAPIStorageQueueable(combinedSpec, 'OPENAPI_SPEC'));
    }
} 