/**
 * Utility class for parsing OpenAPI pseudo-annotations from Apex comments
 */
public with sharing class OpenAPIParser {
    
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
        System.debug('Class body length: ' + classBody.length());
        System.debug('First 200 chars of class body: ' + classBody.substring(0, Math.min(200, classBody.length())));
        
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
        System.debug('Found paths: ' + JSON.serializePretty(paths));
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
        Pattern methodPattern = Pattern.compile('/\\*\\*\\s*\\n\\s*\\*\\s*@openapi\\s*\\n(\\s*\\*\\s*@[^\\n]*\\n)*\\s*\\*/\\s*@(Http\\w+)\\s+.*?\\s+(\\w+)\\s*\\([^)]*\\)');
        Matcher methodMatcher = methodPattern.matcher(classBody);
        
        System.debug('Searching for methods with pattern: ' + methodPattern.pattern());
        
        while (methodMatcher.find()) {
            System.debug('Found method match at position: ' + methodMatcher.start());
            String methodDoc = methodMatcher.group(0);
            String httpMethod = methodMatcher.group(2).toLowerCase();
            String methodName = methodMatcher.group(3);
            
            System.debug('Method name: ' + methodName);
            System.debug('HTTP method: ' + httpMethod);
            System.debug('Method doc: ' + methodDoc);
            
            Map<String, Object> pathInfo = parseMethod(methodDoc);
            if (!paths.containsKey(methodName)) {
                paths.put(methodName, new Map<String, Object>());
            }
            ((Map<String, Object>)paths.get(methodName)).put(httpMethod, pathInfo);
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
        
        // Extract operation ID
        Pattern opPattern = Pattern.compile('@operation\\s+(\\w+)');
        Matcher opMatcher = opPattern.matcher(doc);
        if (opMatcher.find()) {
            methodInfo.put('operationId', opMatcher.group(1));
            System.debug('Found operation ID: ' + opMatcher.group(1));
        }
        
        // Extract summary
        Pattern summaryPattern = Pattern.compile('@summary\\s+(.*?)(?=\\n|$)');
        Matcher summaryMatcher = summaryPattern.matcher(doc);
        if (summaryMatcher.find()) {
            methodInfo.put('summary', summaryMatcher.group(1).trim());
            System.debug('Found summary: ' + summaryMatcher.group(1).trim());
        }
        
        // Extract description
        Pattern descPattern = Pattern.compile('@description\\s+(.*?)(?=\\n|$)');
        Matcher descMatcher = descPattern.matcher(doc);
        if (descMatcher.find()) {
            methodInfo.put('description', descMatcher.group(1).trim());
            System.debug('Found description: ' + descMatcher.group(1).trim());
        }
        
        // Extract parameters
        List<Map<String, Object>> parameters = new List<Map<String, Object>>();
        Pattern paramPattern = Pattern.compile('@param\\s+(\\w+)\\s+(\\w+)\\s+(\\w+)\\s+(.*?)(?=\\n|$)');
        Matcher paramMatcher = paramPattern.matcher(doc);
        while (paramMatcher.find()) {
            Map<String, Object> param = new Map<String, Object>{
                'name' => paramMatcher.group(1),
                'in' => paramMatcher.group(2),
                'type' => paramMatcher.group(3),
                'description' => paramMatcher.group(4).trim(),
                'required' => true
            };
            parameters.add(param);
            System.debug('Found parameter: ' + JSON.serializePretty(param));
        }
        if (!parameters.isEmpty()) {
            methodInfo.put('parameters', parameters);
        }
        
        // Extract responses
        Map<String, Object> responses = new Map<String, Object>();
        Pattern responsePattern = Pattern.compile('@response\\s+(\\d+)\\s+(.*?)(?=\\n|$)');
        Matcher responseMatcher = responsePattern.matcher(doc);
        while (responseMatcher.find()) {
            String code = responseMatcher.group(1);
            String[] parts = responseMatcher.group(2).split('\\s+', 2);
            Map<String, Object> response = new Map<String, Object>{
                'description' => parts[1].trim()
            };
            responses.put(code, response);
            System.debug('Found response: ' + code + ' - ' + parts[1].trim());
        }
        methodInfo.put('responses', responses);
        
        return methodInfo;
    }
} 