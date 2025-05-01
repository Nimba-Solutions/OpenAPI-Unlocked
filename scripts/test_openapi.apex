// Test the OpenAPI parser with our AccountAPI class
Map<String, Object> openApiSpec = OpenAPIParser.parseClass('AccountAPI');

if (openApiSpec == null) {
    System.debug('Failed to parse OpenAPI specification. Class might not exist or have no OpenAPI annotations.');
    return;
}

// Print the results in a readable format
System.debug('=== OpenAPI Specification ===');
if (openApiSpec.containsKey('info')) {
    System.debug('Info: ' + JSON.serializePretty(openApiSpec.get('info')));
} else {
    System.debug('No info section found in OpenAPI specification');
}

if (openApiSpec.containsKey('paths')) {
    System.debug('Paths: ' + JSON.serializePretty(openApiSpec.get('paths')));
} else {
    System.debug('No paths section found in OpenAPI specification');
}

// Let's also test a specific endpoint
if (openApiSpec.containsKey('paths')) {
    Map<String, Object> paths = (Map<String, Object>)openApiSpec.get('paths');
    if (paths.containsKey('getAccount')) {
        Map<String, Object> getAccountPath = (Map<String, Object>)paths.get('getAccount');
        if (getAccountPath.containsKey('httpget')) {
            Map<String, Object> getAccountEndpoint = (Map<String, Object>)getAccountPath.get('httpget');
            
            System.debug('\n=== Get Account Endpoint Details ===');
            System.debug('Operation ID: ' + (getAccountEndpoint.containsKey('operationId') ? getAccountEndpoint.get('operationId') : 'Not found'));
            System.debug('Summary: ' + (getAccountEndpoint.containsKey('summary') ? getAccountEndpoint.get('summary') : 'Not found'));
            System.debug('Description: ' + (getAccountEndpoint.containsKey('description') ? getAccountEndpoint.get('description') : 'Not found'));
            
            if (getAccountEndpoint.containsKey('parameters')) {
                System.debug('Parameters: ' + JSON.serializePretty(getAccountEndpoint.get('parameters')));
            } else {
                System.debug('No parameters found for this endpoint');
            }
            
            if (getAccountEndpoint.containsKey('responses')) {
                System.debug('Responses: ' + JSON.serializePretty(getAccountEndpoint.get('responses')));
            } else {
                System.debug('No responses found for this endpoint');
            }
        } else {
            System.debug('No HTTP GET method found for getAccount endpoint');
        }
    } else {
        System.debug('getAccount endpoint not found in paths');
    }
} 