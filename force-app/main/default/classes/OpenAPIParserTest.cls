@isTest
private class OpenAPIParserTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test data if needed
    }
    
    @isTest
    static void testParseClassesWithNamespace() {
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.parseClasses('test');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('processing', result.get('status'));
        System.assertNotEquals(null, result.get('batchJobId'));
    }
    
    @isTest
    static void testParseClassesWithoutNamespace() {
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.parseClasses();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('processing', result.get('status'));
        System.assertNotEquals(null, result.get('batchJobId'));
    }
    
    @isTest
    static void testParseMethod() {
        String doc = '/**\n' +
                    ' * @openapi\n' +
                    ' * @operation getTest\n' +
                    ' * @summary Get test data\n' +
                    ' * @description Retrieves test data\n' +
                    ' * @tag Test\n' +
                    ' * @security oauth2 read:test\n' +
                    ' * @response 200 {description: "Success", type: "String"}\n' +
                    ' */';
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.parseMethod(doc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('getTest', result.get('operationId'));
        System.assertEquals('Get test data', result.get('summary'));
        System.assertEquals('Retrieves test data', result.get('description'));
    }
    
    @isTest
    static void testGetSchemaRegistry() {
        Test.startTest();
        Map<String, Map<String, Object>> registry = OpenAPIParser.getSchemaRegistry();
        Test.stopTest();
        
        System.assertNotEquals(null, registry);
    }
    
    @isTest
    static void testResetSchemaRegistry() {
        Test.startTest();
        OpenAPIParser.resetSchemaRegistry();
        Test.stopTest();
        
        Map<String, Map<String, Object>> registry = OpenAPIParser.getSchemaRegistry();
        System.assertEquals(0, registry.size());
    }
    
    @isTest
    static void testRegisterSchemaAndGetReference() {
        String typeName = 'TestType';
        Map<String, Object> typeDefinition = new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>()
        };
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.registerSchemaAndGetReference(typeName, typeDefinition);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('#/components/schemas/' + typeName, result.get('$ref'));
    }
    
    @isTest
    static void testRegisterSchemaAndGetReferenceWithBlankName() {
        String typeName = '';
        Map<String, Object> typeDefinition = new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>()
        };
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.registerSchemaAndGetReference(typeName, typeDefinition);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(typeDefinition, result);
    }
    
    @isTest
    static void testExtractParameters() {
        String doc = '/**\n' +
                    ' * @param id path String The record ID\n' +
                    ' * @param name query String The name filter\n' +
                    ' */';
        
        Test.startTest();
        List<Map<String, Object>> result = OpenAPIParser.extractParameters(doc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(2, result.size());
    }
    
    @isTest
    static void testExtractOperationId() {
        String doc = '/**\n' +
                    ' * @operation getTest\n' +
                    ' */';
        
        Test.startTest();
        String result = OpenAPIParser.extractOperationId(doc);
        Test.stopTest();
        
        System.assertEquals('getTest', result);
    }
    
    @isTest
    static void testExtractOperationIdNotFound() {
        String doc = '/**\n' +
                    ' * @summary Get test data\n' +
                    ' */';
        
        Test.startTest();
        String result = OpenAPIParser.extractOperationId(doc);
        Test.stopTest();
        
        System.assertEquals(null, result);
    }
    
    @isTest
    static void testExtractSummary() {
        String doc = '/**\n' +
                    ' * @summary Get test data\n' +
                    ' */';
        
        Test.startTest();
        String result = OpenAPIParser.extractSummary(doc);
        Test.stopTest();
        
        System.assertEquals('Get test data', result);
    }
    
    @isTest
    static void testExtractDescription() {
        String doc = '/**\n' +
                    ' * @description Retrieves test data\n' +
                    ' */';
        
        Test.startTest();
        String result = OpenAPIParser.extractDescription(doc);
        Test.stopTest();
        
        System.assertEquals('Retrieves test data', result);
    }
    
    @isTest
    static void testExtractTags() {
        String doc = '/**\n' +
                    ' * @tag Test\n' +
                    ' * @tag API\n' +
                    ' */';
        
        Test.startTest();
        List<String> result = OpenAPIParser.extractTags(doc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(2, result.size());
        System.assertEquals('Test', result[0]);
        System.assertEquals('API', result[1]);
    }
    
    @isTest
    static void testExtractSecurity() {
        String doc = '/**\n' +
                    ' * @security oauth2 read:test write:test\n' +
                    ' */';
        
        Test.startTest();
        List<Map<String, List<String>>> result = OpenAPIParser.extractSecurity(doc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }
    
    @isTest
    static void testExtractResponses() {
        String doc = '/**\n' +
                    ' * @response 200 {description: "Success", type: "String"}\n' +
                    ' * @response 400 {description: "Error", type: "String"}\n' +
                    ' */';
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.extractResponses(doc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(2, result.size());
    }
    
    @isTest
    static void testExtractRequestBody() {
        String doc = '/**\n' +
                    ' * @requestBody {description: "Test data", type: "String"}\n' +
                    ' */';
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.extractRequestBody(doc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testExtractClassSchema() {
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.extractClassSchema('Account');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testExtractNestedClassSchema() {
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.extractNestedClassSchema('TestAPI', 'TestResponse');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testExtractSObjectProperties() {
        Schema.DescribeSObjectResult describe = Account.sObjectType.getDescribe();
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.extractSObjectProperties(describe);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testParseJsonLikeStructure() {
        String json = 'description: "Test", type: "String"';
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.parseJsonLikeStructure(json);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('Test', result.get('description'));
        System.assertEquals('String', result.get('type'));
    }
    
    @isTest
    static void testParseJsonLikeStructureWithBraces() {
        String json = '{description: "Test", type: "String"}';
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.parseJsonLikeStructure(json);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('Test', result.get('description'));
        System.assertEquals('String', result.get('type'));
    }
    
    @isTest
    static void testGetOpenAPIType() {
        Test.startTest();
        String stringType = OpenAPIParser.getOpenAPIType(Schema.DisplayType.STRING);
        String numberType = OpenAPIParser.getOpenAPIType(Schema.DisplayType.INTEGER);
        String booleanType = OpenAPIParser.getOpenAPIType(Schema.DisplayType.BOOLEAN);
        String dateType = OpenAPIParser.getOpenAPIType(Schema.DisplayType.DATE);
        Test.stopTest();
        
        System.assertEquals('string', stringType);
        System.assertEquals('number', numberType);
        System.assertEquals('boolean', booleanType);
        System.assertEquals('string', dateType);
    }
    
    @isTest
    static void testExtractRestResourceUrlMapping() {
        String classBody = '@RestResource(urlMapping=\'/test/*\')\n' +
                          'global class TestAPI {\n' +
                          '}';
        
        Test.startTest();
        String result = OpenAPIParser.extractRestResourceUrlMapping(classBody);
        Test.stopTest();
        
        System.assertEquals('/test', result);
    }
    
    @isTest
    static void testExtractRestResourceUrlMappingWithTrailingSlash() {
        String classBody = '@RestResource(urlMapping=\'/test/*\')\n' +
                          'global class TestAPI {\n' +
                          '}';
        
        Test.startTest();
        String result = OpenAPIParser.extractRestResourceUrlMapping(classBody);
        Test.stopTest();
        
        System.assertEquals('/test', result);
    }
    
    @isTest
    static void testExtractRestResourceUrlMappingNotFound() {
        String classBody = 'global class TestAPI {\n' +
                          '}';
        
        Test.startTest();
        String result = OpenAPIParser.extractRestResourceUrlMapping(classBody);
        Test.stopTest();
        
        System.assertEquals('', result);
    }
    
    @isTest
    static void testConstructApiPath() {
        String baseUrlMapping = '/test';
        String httpMethod = 'get';
        String methodName = 'getTest';
        List<String> pathParams = new List<String>{'id'};
        
        Test.startTest();
        String result = OpenAPIParser.constructApiPath(baseUrlMapping, httpMethod, methodName, pathParams);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testConstructApiPathPost() {
        String baseUrlMapping = '/test';
        String httpMethod = 'post';
        String methodName = 'createTest';
        List<String> pathParams = new List<String>();
        
        Test.startTest();
        String result = OpenAPIParser.constructApiPath(baseUrlMapping, httpMethod, methodName, pathParams);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testConstructApiPathPut() {
        String baseUrlMapping = '/test';
        String httpMethod = 'put';
        String methodName = 'updateTest';
        List<String> pathParams = new List<String>{'id'};
        
        Test.startTest();
        String result = OpenAPIParser.constructApiPath(baseUrlMapping, httpMethod, methodName, pathParams);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testConstructApiPathDelete() {
        String baseUrlMapping = '/test';
        String httpMethod = 'delete';
        String methodName = 'deleteTest';
        List<String> pathParams = new List<String>{'id'};
        
        Test.startTest();
        String result = OpenAPIParser.constructApiPath(baseUrlMapping, httpMethod, methodName, pathParams);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testStoreAsStaticResource() {
        Map<String, Object> spec = new Map<String, Object>{
            'openapi' => '3.0.0',
            'info' => new Map<String, Object>{
                'title' => 'Test API',
                'version' => '1.0.0'
            }
        };
        
        Test.startTest();
        OpenAPIParser.storeAsStaticResource(spec, 'TEST_SPEC');
        Test.stopTest();
        
        // Test passes if no exception is thrown
    }
    
    @isTest
    static void testExtractPropertiesFromClassBody() {
        String classBody = 'public class TestClass {\n' +
                          '    public String name;\n' +
                          '    public Integer count;\n' +
                          '    public Boolean isActive;\n' +
                          '}';
        
        Test.startTest();
        Map<String, Object> result = OpenAPIParser.extractPropertiesFromClassBody(classBody);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(3, result.size());
    }
}

