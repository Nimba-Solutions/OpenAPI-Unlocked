/**
 * @openapi
 * @title Test API
 * @description API for testing various property patterns
 * @version 1.0.0
 */
@RestResource(urlMapping='/test/*')
global with sharing class TestAPI {
    
    /**
     * @openapi
     * @operation getTest
     * @summary Get test data
     * @description Retrieves test data with various property patterns
     * @tag Test
     * @security oauth2 read:test
     * @response 200 {description: "Test data retrieved successfully", type: "TestAPI.TestResponse"}
     */
    @HttpGet
    global static TestResponse getTest() {
        TestResponse response = new TestResponse();
        response.name = 'Test';
        response.count = 42;
        response.isActive = true;
        response.nested = new NestedClass();
        response.nested.value = 'Nested';
        return response;
    }
    
    /**
     * @openapi
     * @operation createTest
     * @summary Create test data
     * @description Creates test data with various property patterns
     * @tag Test
     * @security oauth2 write:test
     * @requestBody {description: "Test data to create", required: true, type: "TestAPI.TestRequest"}
     * @response 201 {description: "Test data created successfully", type: "TestAPI.TestResponse"}
     */
    @HttpPost
    global static TestResponse createTest() {
        RestRequest req = RestContext.request;
        TestRequest request = (TestRequest)JSON.deserialize(req.requestBody.toString(), TestRequest.class);
        
        TestResponse response = new TestResponse();
        response.name = request.name;
        response.count = request.count;
        response.isActive = request.isActive;
        response.nested = request.nested;
        
        return response;
    }
    
    // Test response class with various property patterns
    global class TestResponse {
        @AuraEnabled public String name;
        public Integer count;
        global Boolean isActive;
        public NestedClass nested;
    }
    
    // Test request class with various property patterns
    global class TestRequest {
        @AuraEnabled public String name;
        public Integer count;
        global Boolean isActive;
        public NestedClass nested;
    }
    
    // Nested class to test inner class handling
    global class NestedClass {
        @AuraEnabled public String value;
        public Integer num;
    }
} 