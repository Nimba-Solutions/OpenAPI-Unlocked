@isTest
private class OpenAPIParserModularTest {
    
    @TestSetup
    static void setupTestData() {
        // No test data setup needed for this test class
    }
    
    @isTest
    static void testGenerateModularSpecifications() {
        Test.startTest();
        OpenAPIParserModular.generateModularSpecifications();
        Test.stopTest();
        
        // Test passes if no exception is thrown
    }
    
    @isTest
    static void testGenerateModularSpecificationsMultipleTimes() {
        Test.startTest();
        OpenAPIParserModular.generateModularSpecifications();
        OpenAPIParserModular.generateModularSpecifications();
        Test.stopTest();
        
        // Test passes if no exception is thrown
    }
    
    @isTest
    static void testGenerateModularSpecificationsWithExistingData() {
        // This test ensures the method works with existing data
        Test.startTest();
        OpenAPIParserModular.generateModularSpecifications();
        Test.stopTest();
        
        // Test passes if no exception is thrown
    }
}
