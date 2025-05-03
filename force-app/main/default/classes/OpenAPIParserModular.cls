/**
 * Modular OpenAPI parser for extremely large APIs
 * Splits the API documentation into modules based on tags/categories
 */
public with sharing class OpenAPIParserModular {
    
    /**
     * Generates modular OpenAPI specifications based on API tags
     * Each API tag gets its own static resource
     */
    public static void generateModularSpecifications() {
        // First, gather all the API tags used in the system
        Set<String> allTags = getAllApiTags();
        System.debug('Found ' + allTags.size() + ' distinct API tags');
        
        // Create a module specification for each tag
        for (String tag : allTags) {
            String safeName = tag.replaceAll('[^a-zA-Z0-9]', '_');
            String resourceName = 'OPENAPI_' + safeName.toUpperCase();
            
            // Start a batch job for each module with the tag filter
            OpenAPIParserModularBatch batch = new OpenAPIParserModularBatch(tag, resourceName);
            Database.executeBatch(batch);
        }
        
        // Also create a master index that references all modules
        createMasterIndex(allTags);
    }
    
    /**
     * Gets all API tags used in the system
     */
    private static Set<String> getAllApiTags() {
        Set<String> tags = new Set<String>();
        
        // Find all classes with OpenAPI annotations - can't filter on Body in SOQL
        List<ApexClass> classes = [
            SELECT Id, Name, Body 
            FROM ApexClass
        ];
        
        Pattern tagPattern = Pattern.compile('@tag\\s+(.*?)(?=\\n|$)');
        Pattern openApiPattern = Pattern.compile('@openapi');
        
        for (ApexClass cls : classes) {
            // First check if this class has OpenAPI annotations
            Matcher openApiMatcher = openApiPattern.matcher(cls.Body);
            if (!openApiMatcher.find()) {
                continue; // Skip this class if it doesn't have OpenAPI annotations
            }
            
            // Now look for tags
            Matcher tagMatcher = tagPattern.matcher(cls.Body);
            while (tagMatcher.find()) {
                String tag = tagMatcher.group(1).trim();
                tags.add(tag);
            }
        }
        
        return tags;
    }
    
    /**
     * Creates a master index of all API modules
     */
    private static void createMasterIndex(Set<String> tags) {
        Map<String, Object> masterSpec = new Map<String, Object>();
        
        // Standard OpenAPI boilerplate
        masterSpec.put('openapi', '3.0.0');
        masterSpec.put('info', new Map<String, Object>{
            'title' => 'API Documentation Index',
            'description' => 'Master index of all API modules',
            'version' => '1.0.0'
        });
        
        // Create an empty paths object (required by OpenAPI spec)
        masterSpec.put('paths', new Map<String, Object>());
        
        // Reference each module in the components section
        Map<String, Object> components = new Map<String, Object>{
            'externalDocs' => new Map<String, Object>()
        };
        
        for (String tag : tags) {
            String safeName = tag.replaceAll('[^a-zA-Z0-9]', '_');
            String resourceName = 'OPENAPI_' + safeName.toUpperCase();
            
            // Add a reference to this module
            components.put(tag, new Map<String, Object>{
                'description' => 'API documentation for ' + tag,
                'externalValue' => '{!URLFOR($Resource.' + resourceName + ')}'
            });
        }
        
        masterSpec.put('components', components);
        
        // Store the master index
        System.enqueueJob(new OpenAPIStorageQueueable(masterSpec, 'OPENAPI_MASTER_INDEX'));
    }
} 