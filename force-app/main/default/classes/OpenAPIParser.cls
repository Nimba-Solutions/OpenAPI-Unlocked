/**
 * Utility class for parsing OpenAPI pseudo-annotations from Apex comments
 */
public with sharing class OpenAPIParser {
    
    public class OpenAPIParserException extends Exception {}
    
    /**
     * Parses OpenAPI information from a class's comments
     * @param className The name of the class to parse
     * @return Map<String, Object> containing the parsed OpenAPI information
     */
    public static Map<String, Object> parseClass(String className) {
        // Query the ApexClass sObject to get the actual class body
        List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :className LIMIT 1];
        if (classes.isEmpty()) {
            System.debug('No ApexClass found with name: ' + className);
            return null;
        }
        
        String classBody = classes[0].Body;
        System.debug('=== Processing class: ' + className + ' ===');
        System.debug('Class body length: ' + classBody.length());
        System.debug('First 500 chars of class body: ' + classBody.substring(0, Math.min(500, classBody.length())));
        
        Map<String, Object> result = new Map<String, Object>();
        
        // Extract class-level OpenAPI annotations
        Pattern classPattern = Pattern.compile('/\\*\\*\\s*\\n\\s*\\*\\s*@openapi\\s*\\n\\s*\\*\\s*@title\\s+(.*?)\\n\\s*\\*\\s*@description\\s+(.*?)\\n\\s*\\*\\s*@version\\s+(.*?)\\n\\s*\\*/');
        Matcher classMatcher = classPattern.matcher(classBody);
        
        if (classMatcher.find()) {
            System.debug('Found class-level OpenAPI annotation');
            Map<String, Object> info = new Map<String, Object>{
                'title' => classMatcher.group(1).trim(),
                'description' => classMatcher.group(2).trim(),
                'version' => classMatcher.group(3).trim()
            };
            result.put('info', info);
        } else {
            System.debug('No class-level OpenAPI annotation found');
        }
        
        // Extract method-level OpenAPI annotations
        Map<String, Object> paths = parseMethods(classBody);
        System.debug('=== Found paths: ' + JSON.serializePretty(paths) + ' ===');
        result.put('paths', paths);
        
        return result;
    }
    
    /**
     * Parses OpenAPI paths from method documentation
     * @param classBody The class body to parse
     * @return Map<String, Object> containing the paths section
     */
    private static Map<String, Object> parseMethods(String classBody) {
        Map<String, Object> paths = new Map<String, Object>();
        
        // Find all method documentation blocks
        Pattern methodPattern = Pattern.compile('/\\*\\*\\s*\\n(\\s*\\*\\s*@[^\\n]*\\n)*\\s*\\*/\\s*\\n*\\s*@(Http\\w+)\\s+.*?\\s+(\\w+)\\s*\\([^)]*\\)');
        Matcher methodMatcher = methodPattern.matcher(classBody);
        
        System.debug('=== Searching for methods with pattern: ' + methodPattern.pattern() + ' ===');
        
        while (methodMatcher.find()) {
            System.debug('=== Found method match at position: ' + methodMatcher.start() + ' ===');
            String methodDoc = methodMatcher.group(0);
            String httpMethod = methodMatcher.group(2).toLowerCase().replace('http', '');
            String methodName = methodMatcher.group(3);
            
            // Format path with leading slash and path parameters
            String path = '/' + methodName;
            List<Map<String, Object>> parameters = extractParameters(methodDoc);
            for (Map<String, Object> param : parameters) {
                if (param.get('in') == 'path') {
                    String paramName = (String)param.get('name');
                    path = path + '/{' + paramName + '}';
                }
            }
            
            System.debug('Method name: ' + methodName);
            System.debug('HTTP method: ' + httpMethod);
            System.debug('Method doc: ' + methodDoc);
            
            Map<String, Object> pathInfo = parseMethod(methodDoc);
            System.debug('Parsed method info: ' + JSON.serializePretty(pathInfo));
            
            if (!paths.containsKey(path)) {
                paths.put(path, new Map<String, Object>());
            }
            ((Map<String, Object>)paths.get(path)).put(httpMethod, pathInfo);
        }
        
        return paths;
    }
    
    /**
     * Parses a single method's OpenAPI documentation
     * @param doc The method documentation to parse
     * @return Map<String, Object> containing the method's OpenAPI information
     */
    private static Map<String, Object> parseMethod(String doc) {
        Map<String, Object> methodInfo = new Map<String, Object>();
        
        // Extract basic method info
        methodInfo.put('operationId', extractOperationId(doc));
        methodInfo.put('summary', extractSummary(doc));
        methodInfo.put('description', extractDescription(doc));
        
        // Extract tags
        List<String> tags = extractTags(doc);
        if (!tags.isEmpty()) {
            methodInfo.put('tags', tags);
        }
        
        // Extract security requirements
        List<Map<String, List<String>>> security = extractSecurity(doc);
        if (!security.isEmpty()) {
            methodInfo.put('security', security);
        }
        
        // Extract parameters
        List<Map<String, Object>> parameters = extractParameters(doc);
        if (!parameters.isEmpty()) {
            methodInfo.put('parameters', parameters);
        }
        
        // Extract request body
        Map<String, Object> requestBody = extractRequestBody(doc);
        if (!requestBody.isEmpty()) {
            methodInfo.put('requestBody', requestBody);
        }
        
        // Extract responses
        Map<String, Object> responses = extractResponses(doc);
        methodInfo.put('responses', responses);
        
        return methodInfo;
    }
    
    private static String extractOperationId(String doc) {
        Pattern opPattern = Pattern.compile('@operation\\s+(\\w+)');
        Matcher opMatcher = opPattern.matcher(doc);
        return opMatcher.find() ? opMatcher.group(1) : null;
    }
    
    private static String extractSummary(String doc) {
        Pattern summaryPattern = Pattern.compile('@summary\\s+(.*?)(?=\\n|$)');
        Matcher summaryMatcher = summaryPattern.matcher(doc);
        return summaryMatcher.find() ? summaryMatcher.group(1).trim() : null;
    }
    
    private static String extractDescription(String doc) {
        Pattern descPattern = Pattern.compile('@description\\s+(.*?)(?=\\n|$)');
        Matcher descMatcher = descPattern.matcher(doc);
        return descMatcher.find() ? descMatcher.group(1).trim() : null;
    }
    
    private static List<String> extractTags(String doc) {
        List<String> tags = new List<String>();
        Pattern tagPattern = Pattern.compile('@tag\\s+(.*?)(?=\\n|$)');
        Matcher tagMatcher = tagPattern.matcher(doc);
        while (tagMatcher.find()) {
            tags.add(tagMatcher.group(1).trim());
        }
        return tags;
    }
    
    private static List<Map<String, List<String>>> extractSecurity(String doc) {
        List<Map<String, List<String>>> security = new List<Map<String, List<String>>>();
        Pattern securityPattern = Pattern.compile('@security\\s+(\\w+)(?:\\s+(.*?))?(?=\\n|$)');
        Matcher securityMatcher = securityPattern.matcher(doc);
        while (securityMatcher.find()) {
            String scheme = securityMatcher.group(1);
            String scopes = securityMatcher.group(2);
            Map<String, List<String>> securityItem = new Map<String, List<String>>();
            List<String> scopeList = new List<String>();
            if (scopes != null) {
                scopeList = scopes.split('\\s+');
            }
            securityItem.put(scheme, scopeList);
            security.add(securityItem);
        }
        return security;
    }
    
    private static List<Map<String, Object>> extractParameters(String doc) {
        List<Map<String, Object>> parameters = new List<Map<String, Object>>();
        Pattern paramPattern = Pattern.compile('@param\\s+(\\w+)\\s+(\\w+)\\s+(\\w+)\\s+(.*?)(?=\\n|$)');
        Matcher paramMatcher = paramPattern.matcher(doc);
        while (paramMatcher.find()) {
            String paramName = paramMatcher.group(1);
            String paramIn = paramMatcher.group(2);
            String paramType = paramMatcher.group(3);
            String paramDesc = paramMatcher.group(4).trim();
            
            // Convert Apex type to OpenAPI type
            String openApiType = 'string'; // default
            if (paramType.equalsIgnoreCase('Boolean')) {
                openApiType = 'boolean';
            } else if (paramType.equalsIgnoreCase('Integer') || paramType.equalsIgnoreCase('Decimal') || paramType.equalsIgnoreCase('Double')) {
                openApiType = 'number';
            }
            
            Map<String, Object> param = new Map<String, Object>{
                'name' => paramName,
                'in' => paramIn,
                'required' => true,
                'description' => paramDesc,
                'schema' => new Map<String, Object>{
                    'type' => openApiType
                }
            };
            parameters.add(param);
        }
        return parameters;
    }
    
    private static Map<String, Object> extractRequestBody(String doc) {
        Map<String, Object> requestBody = new Map<String, Object>();
        Pattern requestBodyPattern = Pattern.compile('@requestBody\\s+\\{([^}]*)\\}(?=\\n|$)');
        Matcher requestBodyMatcher = requestBodyPattern.matcher(doc);
        if (requestBodyMatcher.find()) {
            String requestBodyJson = requestBodyMatcher.group(1);
            Map<String, Object> parsedJson = parseJsonLikeStructure(requestBodyJson);
            
            // Create the base request body structure
            requestBody.put('required', true);
            requestBody.put('description', parsedJson.get('description'));
            
            // Create the content structure
            Map<String, Object> content = new Map<String, Object>();
            Map<String, Object> jsonContent = new Map<String, Object>();
            Map<String, Object> schema = new Map<String, Object>();
            
            // If content is specified directly in the annotation
            if (parsedJson.containsKey('content')) {
                Map<String, Object> contentJson = (Map<String, Object>)parsedJson.get('content');
                if (contentJson.containsKey('application/json')) {
                    Map<String, Object> jsonSchema = (Map<String, Object>)((Map<String, Object>)contentJson.get('application/json')).get('schema');
                    if (jsonSchema != null) {
                        schema = jsonSchema;
                        jsonContent.put('schema', schema);
                        content.put('application/json', jsonContent);
                        requestBody.put('content', content);
                        return requestBody;
                    }
                }
            }
            
            // If type is specified, try to extract properties from the referenced type
            if (parsedJson.containsKey('type')) {
                String typeName = (String)parsedJson.get('type');
                List<String> typeNameParts = typeName.split('\\.');
                
                if (typeNameParts.size() == 2) {
                    // This is a nested class reference (e.g. "TestAPI.TestRequest")
                    String outerClassName = typeNameParts[0];
                    String innerClassName = typeNameParts[1];
                    
                    // Find the outer class
                    List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :outerClassName LIMIT 1];
                    if (!classes.isEmpty()) {
                        String classBody = classes[0].Body;
                        
                        // Find the inner class definition
                        Pattern innerClassPattern = Pattern.compile('(?:public|global|private|protected)?\\s+class\\s+' + innerClassName + '\\s*\\{([^}]*?)\\}');
                        Matcher innerClassMatcher = innerClassPattern.matcher(classBody);
                        
                        if (innerClassMatcher.find()) {
                            String innerClassBody = innerClassMatcher.group(1);
                            Map<String, Object> classProperties = extractPropertiesFromClassBody(innerClassBody);
                            if (!classProperties.isEmpty()) {
                                schema.put('type', 'object');
                                schema.put('properties', classProperties);
                                jsonContent.put('schema', schema);
                                content.put('application/json', jsonContent);
                                requestBody.put('content', content);
                                return requestBody;
                            }
                        }
                    }
                } else {
                    // This is a regular class reference
                    List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :typeName LIMIT 1];
                    if (!classes.isEmpty()) {
                        Map<String, Object> classProperties = extractPropertiesFromClassBody(classes[0].Body);
                        if (!classProperties.isEmpty()) {
                            schema.put('type', 'object');
                            schema.put('properties', classProperties);
                            jsonContent.put('schema', schema);
                            content.put('application/json', jsonContent);
                            requestBody.put('content', content);
                            return requestBody;
                        }
                    }
                }
            }
            
            // If no properties were found, create an empty schema
            schema.put('type', 'object');
            schema.put('properties', new Map<String, Object>());
            jsonContent.put('schema', schema);
            content.put('application/json', jsonContent);
            requestBody.put('content', content);
        }
        return requestBody;
    }
    
    private static Map<String, Object> parseJsonLikeStructure(String json) {
        Map<String, Object> result = new Map<String, Object>();
        
        // Remove outer braces if present
        json = json.trim();
        if (json.startsWith('{') && json.endsWith('}')) {
            json = json.substring(1, json.length() - 1).trim();
        }
        
        // Split into key-value pairs
        List<String> pairs = new List<String>();
        Integer braceCount = 0;
        Integer startPos = 0;
        
        for (Integer i = 0; i < json.length(); i++) {
            String c = json.substring(i, i + 1);
            if (c == '{') braceCount++;
            if (c == '}') braceCount--;
            if (c == ',' && braceCount == 0) {
                pairs.add(json.substring(startPos, i).trim());
                startPos = i + 1;
            }
        }
        if (startPos < json.length()) {
            pairs.add(json.substring(startPos).trim());
        }
        
        for (String pair : pairs) {
            if (pair.contains(':')) {
                List<String> parts = pair.split(':', 2);
                String key = parts[0].trim();
                String value = parts[1].trim();
                
                // Remove quotes if present
                if (value.startsWith('"') && value.endsWith('"')) {
                    value = value.substring(1, value.length() - 1);
                }
                
                // Handle nested objects
                if (value.startsWith('{') && value.endsWith('}')) {
                    result.put(key, parseJsonLikeStructure(value));
                } else {
                    result.put(key, value);
                }
            }
        }
        
        return result;
    }
    
    private static Map<String, Object> extractResponses(String doc) {
        Map<String, Object> responses = new Map<String, Object>();
        Pattern responsePattern = Pattern.compile('@response\\s+(\\d+)\\s+\\{(.*?)\\}(?=\\n|$)');
        Matcher responseMatcher = responsePattern.matcher(doc);
        while (responseMatcher.find()) {
            String code = responseMatcher.group(1);
            String responseJson = responseMatcher.group(2);
            
            // Parse the JSON-like format into a Map
            Map<String, Object> response = new Map<String, Object>();
            Pattern fieldPattern = Pattern.compile('(\\w+):\\s*"([^"]*)"|(\\w+):\\s*\\{(.*?)\\}|(\\w+):\\s*(true|false)');
            Matcher fieldMatcher = fieldPattern.matcher(responseJson);
            while (fieldMatcher.find()) {
                String key = fieldMatcher.group(1) != null ? fieldMatcher.group(1) : 
                           (fieldMatcher.group(3) != null ? fieldMatcher.group(3) : fieldMatcher.group(5));
                String value = fieldMatcher.group(2) != null ? fieldMatcher.group(2) : 
                             (fieldMatcher.group(4) != null ? fieldMatcher.group(4) : fieldMatcher.group(6));
                response.put(key, value);
            }
            
            // If type is specified, add schema
            if (response.containsKey('type')) {
                String type = (String)response.get('type');
                Map<String, Object> openApiSchema = new Map<String, Object>();
                
                try {
                    // First try to get the SObject describe for the type
                    List<String> types = new List<String>{type};
                    List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(types);
                    
                    if (!results.isEmpty()) {
                        Schema.DescribeSObjectResult describe = results[0];
                        
                        // Build schema properties
                        Map<String, Object> properties = new Map<String, Object>();
                        for (Schema.SObjectField field : describe.fields.getMap().values()) {
                            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                            String fieldName = fieldDescribe.getName();
                            String fieldType = getOpenAPIType(fieldDescribe.getType());
                            
                            Map<String, Object> property = new Map<String, Object>{
                                'type' => fieldType
                            };
                            
                            if (fieldDescribe.getLabel() != null) {
                                property.put('description', fieldDescribe.getLabel());
                            }
                            
                            properties.put(fieldName, property);
                        }
                        
                        openApiSchema.put('type', 'object');
                        openApiSchema.put('properties', properties);
                        
                        response.put('content', new Map<String, Object>{
                            'application/json' => new Map<String, Object>{
                                'schema' => openApiSchema
                            }
                        });
                    } else {
                        // If not an SObject, try to find an Apex class definition
                        List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :type LIMIT 1];
                        if (!classes.isEmpty()) {
                            String classBody = classes[0].Body;
                            
                            // Look for property definitions in the class
                            Map<String, Object> properties = new Map<String, Object>();
                            Pattern propertyPattern = Pattern.compile('(public|global)\\s+(\\w+)\\s+(\\w+);');
                            Matcher propertyMatcher = propertyPattern.matcher(classBody);
                            
                            while (propertyMatcher.find()) {
                                String fieldType = propertyMatcher.group(2);
                                String fieldName = propertyMatcher.group(3);
                                
                                // Convert Apex type to OpenAPI type
                                String openApiType = 'string'; // default
                                if (fieldType.equalsIgnoreCase('Boolean')) {
                                    openApiType = 'boolean';
                                } else if (fieldType.equalsIgnoreCase('Integer') || fieldType.equalsIgnoreCase('Decimal') || fieldType.equalsIgnoreCase('Double')) {
                                    openApiType = 'number';
                                }
                                
                                properties.put(fieldName, new Map<String, Object>{
                                    'type' => openApiType
                                });
                            }
                            
                            if (!properties.isEmpty()) {
                                openApiSchema.put('type', 'object');
                                openApiSchema.put('properties', properties);
                                
                                response.put('content', new Map<String, Object>{
                                    'application/json' => new Map<String, Object>{
                                        'schema' => openApiSchema
                                    }
                                });
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error generating schema for type ' + type + ': ' + e.getMessage());
                }
                
                // Remove type as it's not part of OpenAPI spec
                response.remove('type');
            }
            
            responses.put(code, response);
        }
        return responses;
    }
    
    private static String getOpenAPIType(Schema.DisplayType fieldType) {
        switch on fieldType {
            when STRING, TEXTAREA, PICKLIST, MULTIPICKLIST, EMAIL, PHONE, URL, ID, REFERENCE {
                return 'string';
            }
            when INTEGER, CURRENCY, DOUBLE, PERCENT {
                return 'number';
            }
            when BOOLEAN {
                return 'boolean';
            }
            when DATE {
                return 'string';
            }
            when DATETIME {
                return 'string';
            }
            when else {
                return 'string';
            }
        }
    }
    
    /**
     * Stores the OpenAPI specification as a Static Resource
     * @param spec The OpenAPI specification to store
     * @param resourceName The name of the Static Resource
     */
    public static void storeAsStaticResource(Map<String, Object> spec, String resourceName) {
        // Convert spec to JSON string
        String jsonSpec = JSON.serializePretty(spec);
        
        // First try to get the existing Static Resource
        HttpRequest getReq = new HttpRequest();
        getReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/query?q=SELECT+Id+FROM+StaticResource+WHERE+Name=\'' + resourceName + '\'');
        getReq.setMethod('GET');
        getReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        
        Http http = new Http();
        HttpResponse getRes = http.send(getReq);
        
        String resourceId = null;
        if (getRes.getStatusCode() == 200) {
            Map<String, Object> queryResult = (Map<String, Object>)JSON.deserializeUntyped(getRes.getBody());
            List<Object> records = (List<Object>)queryResult.get('records');
            if (!records.isEmpty()) {
                Map<String, Object> record = (Map<String, Object>)records[0];
                resourceId = (String)record.get('Id');
            }
        }
        
        // Create or update the Static Resource
        HttpRequest req = new HttpRequest();
        if (resourceId != null) {
            // Update existing resource
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/StaticResource/' + resourceId);
            req.setMethod('PATCH');
        } else {
            // Create new resource
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/StaticResource');
            req.setMethod('POST');
        }
        
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        
        // Create the Static Resource body with correct field names
        Map<String, Object> body = new Map<String, Object>{
            'Name' => resourceName,
            'ContentType' => 'application/json',
            'CacheControl' => 'Public',
            'Body' => EncodingUtil.base64Encode(Blob.valueOf(jsonSpec))
        };
        
        req.setBody(JSON.serialize(body));
        
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 201 && res.getStatusCode() != 204) {
            throw new OpenAPIParserException('Failed to ' + (resourceId != null ? 'update' : 'create') + ' Static Resource: ' + res.getBody());
        }
    }
    
    /**
     * Parses OpenAPI information from all classes in the default namespace
     * @return Map<String, Object> containing the combined OpenAPI information
     */
    public static Map<String, Object> parseClasses() {
        return parseClasses(null);
    }
    
    /**
     * Parses OpenAPI information from all classes in a namespace
     * @param namespace The namespace to parse (null for default namespace)
     * @return Map<String, Object> containing the combined OpenAPI information
     */
    public static Map<String, Object> parseClasses(String namespace) {
        // Query all Apex classes in the namespace
        String query = 'SELECT Id, Name, Body FROM ApexClass';
        if (namespace != null) {
            query += ' WHERE NamespacePrefix = :namespace';
        }
        List<ApexClass> classes = Database.query(query);
        
        System.debug('Found ' + classes.size() + ' classes in namespace: ' + (namespace == null ? 'default' : namespace));
        
        Map<String, Object> combinedSpec = new Map<String, Object>();
        Map<String, Object> combinedPaths = new Map<String, Object>();
        String combinedTitle = 'Salesforce REST API';
        String combinedDescription = 'Combined REST API documentation';
        String combinedVersion = '1.0.0';
        
        // Add OpenAPI version
        combinedSpec.put('openapi', '3.0.0');
        
        for (ApexClass apexClass : classes) {
            System.debug('Processing class: ' + apexClass.Name);
            Map<String, Object> classSpec = parseClass(apexClass.Name);
            
            if (classSpec != null) {
                // Merge info section
                if (classSpec.containsKey('info')) {
                    Map<String, Object> info = (Map<String, Object>)classSpec.get('info');
                    if (info.containsKey('title')) {
                        combinedTitle = (String)info.get('title');
                    }
                    if (info.containsKey('description')) {
                        combinedDescription = (String)info.get('description');
                    }
                    if (info.containsKey('version')) {
                        combinedVersion = (String)info.get('version');
                    }
                }
                
                // Merge paths
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
        
        // Set the combined info
        combinedSpec.put('info', new Map<String, Object>{
            'title' => combinedTitle,
            'description' => combinedDescription,
            'version' => combinedVersion
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
        
        System.debug('Combined OpenAPI specification: ' + JSON.serializePretty(combinedSpec));
        
        // Store as Static Resource
        storeAsStaticResource(combinedSpec, 'OPENAPI_SPEC');
        
        return combinedSpec;
    }
    
    private static Map<String, Object> extractPropertiesFromClassBody(String classBody) {
        Map<String, Object> properties = new Map<String, Object>();
        Pattern propertyPattern = Pattern.compile('(public|global)\\s+(\\w+)\\s+(\\w+)\\s*;');
        Matcher propertyMatcher = propertyPattern.matcher(classBody);
        
        while (propertyMatcher.find()) {
            String fieldType = propertyMatcher.group(2);
            String fieldName = propertyMatcher.group(3);
            
            // Convert Apex type to OpenAPI type
            String openApiType = 'string';
            if (fieldType.equalsIgnoreCase('Boolean')) {
                openApiType = 'boolean';
            } else if (fieldType.equalsIgnoreCase('Integer') || fieldType.equalsIgnoreCase('Decimal') || fieldType.equalsIgnoreCase('Double')) {
                openApiType = 'number';
            }
            
            properties.put(fieldName, new Map<String, Object>{
                'type' => openApiType
            });
        }
        
        return properties;
    }
}