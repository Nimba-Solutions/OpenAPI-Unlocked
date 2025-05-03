// Regenerate full OpenAPI specification using the updated path constructor
System.debug('Starting OpenAPI regeneration...');
Map<String, Object> result = OpenAPIParser.parseClasses();
System.debug('Regeneration started: ' + result); 