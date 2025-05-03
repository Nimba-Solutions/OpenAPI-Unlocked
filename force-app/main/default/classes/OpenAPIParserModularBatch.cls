/**
 * Batch class for generating modular OpenAPI specs by tag
 * For extremely large APIs, each tag gets its own specification
 */
public class OpenAPIParserModularBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private String apiTag;
    private String resourceName;
    private Map<String, Object> combinedSpec;
    private Map<String, Object> combinedPaths;
    
    /**
     * Constructor for creating a module for a specific API tag
     * @param apiTag The API tag to filter by
     * @param resourceName The name for the resulting Static Resource
     */
    public OpenAPIParserModularBatch(String apiTag, String resourceName) {
        this.apiTag = apiTag;
        this.resourceName = resourceName;
        this.combinedSpec = new Map<String, Object>();
        this.combinedPaths = new Map<String, Object>();
        
        // Initialize OpenAPI spec
        this.combinedSpec.put('openapi', '3.0.0');
        this.combinedSpec.put('info', new Map<String, Object>{
            'title' => apiTag + ' API',
            'description' => 'API documentation for ' + apiTag,
            'version' => '1.0.0'
        });
    }
    
    /**
     * Start method to query classes without filtering on Body (which isn't supported in SOQL)
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // We can't filter on Body in SOQL, so we'll get all classes and filter in execute
        return Database.getQueryLocator(
            'SELECT Id, Name, Body FROM ApexClass'
        );
    }
    
    /**
     * Execute method that processes each batch
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<ApexClass> classes = (List<ApexClass>)scope;
        System.debug('Processing batch of ' + classes.size() + ' classes for tag: ' + apiTag);
        
        List<ApexClass> filteredClasses = new List<ApexClass>();
        Pattern openApiPattern = Pattern.compile('@openapi');
        Pattern tagPattern = Pattern.compile('@tag\\s+' + Pattern.quote(apiTag));
        
        // First filter classes to only those with our specific tag
        for (ApexClass apexClass : classes) {
            String body = apexClass.Body;
            // Check if this class has both OpenAPI annotations and our specific tag
            Matcher openApiMatcher = openApiPattern.matcher(body);
            if (!openApiMatcher.find()) {
                continue;
            }
            
            Matcher tagMatcher = tagPattern.matcher(body);
            if (!tagMatcher.find()) {
                continue;
            }
            
            filteredClasses.add(apexClass);
        }
        
        System.debug('Filtered down to ' + filteredClasses.size() + ' classes with tag: ' + apiTag);
        
        for (ApexClass apexClass : filteredClasses) {
            // Check remaining governors before processing each class
            if (Limits.getHeapSize() >= Limits.getLimitHeapSize() * 0.9 || 
                Limits.getQueries() >= Limits.getLimitQueries() - 5) {
                System.debug('Approaching governor limits, stopping batch processing early');
                break;
            }
            
            System.debug('Processing class: ' + apexClass.Name);
            
            // Parse the class specifically looking for methods with our tag
            Map<String, Object> classSpec = parseClassForTag(apexClass, apiTag);
            
            if (classSpec != null && classSpec.containsKey('paths')) {
                // Merge paths
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
    
    /**
     * Finish method that finalizes and stores the module
     */
    public void finish(Database.BatchableContext bc) {
        // Add the paths to the spec
        combinedSpec.put('paths', combinedPaths);
        
        // Add servers section with the org's instance URL
        String baseUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest';
        combinedSpec.put('servers', new List<Map<String, Object>>{
            new Map<String, Object>{
                'url' => baseUrl,
                'description' => 'Salesforce Apex REST API'
            }
        });
        
        // Add the single tag that this module is for
        combinedSpec.put('tags', new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => apiTag,
                'description' => 'Endpoints for ' + apiTag
            }
        });
        
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
                                'api' => 'Access and manage your data (api)'
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
        
        System.debug('Finished creating modular spec for tag: ' + apiTag);
        System.enqueueJob(new OpenAPIStorageQueueable(combinedSpec, resourceName));
    }
    
    /**
     * Parses a class looking only for methods with the specified tag
     */
    private Map<String, Object> parseClassForTag(ApexClass apexClass, String tagToFind) {
        Map<String, Object> result = new Map<String, Object>();
        Map<String, Object> paths = new Map<String, Object>();
        
        String classBody = apexClass.Body;
        
        // Extract RestResource URL mapping if present
        String baseUrlMapping = extractRestResourceUrlMapping(classBody);
        
        // Find all method documentation blocks
        Pattern methodPattern = Pattern.compile('/\\*\\*\\s*\\n(\\s*\\*\\s*@[^\\n]*\\n)*\\s*\\*/\\s*\\n*\\s*@(Http\\w+)\\s+.*?\\s+(\\w+)\\s*\\([^)]*\\)');
        Matcher methodMatcher = methodPattern.matcher(classBody);
        
        while (methodMatcher.find()) {
            String methodDoc = methodMatcher.group(0);
            
            // Check if this method has our tag
            if (!methodDoc.contains('@tag ' + tagToFind)) {
                continue;
            }
            
            String httpMethod = methodMatcher.group(2).toLowerCase().replace('http', '');
            String methodName = methodMatcher.group(3);
            
            // Check for path parameters
            Pattern paramPattern = Pattern.compile('@param\\s+(\\w+)\\s+path\\s+.*');
            Matcher paramMatcher = paramPattern.matcher(methodDoc);
            List<String> pathParams = new List<String>();
            while (paramMatcher.find()) {
                pathParams.add(paramMatcher.group(1));
            }
            
            // Use shared utility method to construct the path
            String path = OpenAPIParser.constructApiPath(baseUrlMapping, httpMethod, methodName, pathParams);
            
            // Use OpenAPIParser's parseMethod to get the details
            Map<String, Object> methodInfo = OpenAPIParser.parseMethod(methodDoc);
            
            // No longer removing security - method level will take precedence over root level
            
            if (!paths.containsKey(path)) {
                paths.put(path, new Map<String, Object>());
            }
            ((Map<String, Object>)paths.get(path)).put(httpMethod, methodInfo);
        }
        
        if (!paths.isEmpty()) {
            result.put('paths', paths);
        }
        
        return result;
    }
    
    /**
     * Extract the URL mapping from @RestResource annotation
     * @param classBody The class body to inspect
     * @return The URL mapping string or empty string if not found
     */
    private String extractRestResourceUrlMapping(String classBody) {
        Pattern restResourcePattern = Pattern.compile('@RestResource\\s*\\(\\s*urlMapping\\s*=\\s*[\'"]([^\'"]*)[\'"]\\s*\\)');
        Matcher matcher = restResourcePattern.matcher(classBody);
        if (matcher.find()) {
            String urlMapping = matcher.group(1);
            // Remove trailing /* if present
            if (urlMapping.endsWith('/*')) {
                urlMapping = urlMapping.substring(0, urlMapping.length() - 2);
            }
            // Ensure it starts with /
            if (!urlMapping.startsWith('/')) {
                urlMapping = '/' + urlMapping;
            }
            return urlMapping;
        }
        return '';
    }
} 