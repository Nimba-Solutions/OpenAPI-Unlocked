# OpenAPI Unlocked

OpenAPI Unlocked brings the power of OpenAPI (Swagger) documentation to Salesforce development through an unlocked package. Enable your team to create beautiful, interactive API documentation with minimal effort - directly on Salesforce!

## Overview

OpenAPI Unlocked allows Salesforce developers to add simple annotations to their Apex classes that automatically generate standardized OpenAPI (Swagger) documentation. Publish your API documentation directly to Experience Cloud sites (experimental) and give your integration partners the gift of clear, interactive documentation.

## Key Features

- **Reduce Integration Friction**: Clear documentation means faster partner onboarding and fewer support tickets
- **Stay in Sync**: Documentation is generated directly from your code, so it's always up-to-date
- **Developer Friendly**: Simple annotations that feel familiar to Java developers
- **Complex Type Support**: Automatically generates schema definitions for SObjects and Apex-defined types
- **Governor Limit Safe**: Batch processing ensures reliability with any codebase size
- **100% Native**: Built as a Salesforce unlocked package with no external dependencies

## Basic Usage

### 1. Add Swagger annotations to your Apex classes:

```apex
/**
 * @openapi
 * @title Account Management API
 * @description API for managing Account records
 * @version 1.0.0
 */
@RestResource(urlMapping='/account/*')
global with sharing class AccountAPI {
    
    /**
     * @openapi
     * @operation getAccount
     * @summary Get an account by ID
     * @description Retrieves an account record by its ID
     * @tag Account
     * @security oauth2 read:accounts
     * @param id path string Account ID
     * @response 200 {description: "Account retrieved successfully", type: "Account"}
     * @response 404 {description: "Account not found"}
     */
    @HttpGet
    global static Account getAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        List<Account> accounts = [SELECT Id, Name, Industry, Phone FROM Account WHERE Id = :accountId];
        if (accounts.isEmpty()) {
            RestContext.response.statusCode = 404;
            return null;
        }
        
        return accounts[0];
    }
    
    /**
     * @openapi
     * @operation createAccount
     * @summary Create a new account
     * @description Creates a new account record
     * @tag Account
     * @requestBody {description: "Account data to create", type: "Account"}
     * @response 201 {description: "Account created successfully", type: "Account"}
     * @response 400 {description: "Invalid input"}
     */
    @HttpPost
    global static Account createAccount() {
        RestRequest req = RestContext.request;
        Account newAccount = (Account)JSON.deserialize(
            req.requestBody.toString(), 
            Account.class
        );
        
        try {
            insert newAccount;
            RestContext.response.statusCode = 201;
            return newAccount;
        } catch (Exception e) {
            RestContext.response.statusCode = 400;
            return null;
        }
    }
}
```

### 2. Run `OpenAPIParser.parseClasses()`

Generate the OpenAPI documentation by running this static method in Anonymous Apex:

```apex
// Basic usage
OpenAPIParser.parseClasses();

// Optionally provide a specific namespace
OpenAPIParser.parseClasses('acme');
```

This will:
- Identify and parse classes with OpenApi annotations
- Automatically register and include all referenced schemas
- Store results in one or many static resource
- Return job status information while processing runs in the background

### 3. Download the resulting StaticResource from your Org

### 4. Upload your spec into your preferred tool (e.g. Postman, SwaggerUI)
![image](https://github.com/user-attachments/assets/65422716-e39b-42df-af07-5f1f7edce6c1)

## Annotation Reference

OpenAPI Unlocked supports the following annotations:

| Annotation     | Level  | Description                                                      | Example                                                      |
|----------------|--------|------------------------------------------------------------------|--------------------------------------------------------------|
| `@openapi`     | All    | Marks a class or method for OpenAPI processing                   | `@openapi`                                                    |
| `@title`       | Class  | API title                                                        | `@title Account Management API`                              |
| `@description` | All    | Detailed description                                             | `@description API for managing Account records`              |
| `@version`     | Class  | API version                                                      | `@version 1.0.0`                                             |
| `@operation`   | Method | Unique operation ID                                              | `@operation getAccount`                                      |
| `@summary`     | Method | Brief summary                                                    | `@summary Get an account by ID`                              |
| `@tag`         | Method | API grouping tag                                                 | `@tag Account`                                               |
| `@security`    | Method | Security requirements                                            | `@security oauth2 read:accounts write:accounts`              |
| `@param`       | Method | Path/query parameters                                            | `@param id path string Account ID`                           |
| `@requestBody` | Method | Request body definition                                          | `@requestBody {description: "Account data", type: "Account"}` |
| `@response`    | Method | Response definition                                              | `@response 200 {description: "Success", type: "Account"}`    |

## Advanced Type Handling

OpenAPI Unlocked automatically extracts and registers schemas for:

1. **Standard Salesforce SObjects** (Account, Contact, etc.)
2. **Custom SObjects** specific to your org
3. **Apex-Defined Types** (both top-level and nested classes)

For example, with a custom class:

```apex
global class TestAPI {
    // Nested request schema
    global class TestRequest {
        global String name;
        global Integer count;
        global Boolean isActive;
        global String nested;
    }
    
    // Nested response schema
    global class TestResponse {
        global String name;
        global Integer count;
        global Boolean isActive;
        global String nested;
    }
    
    /**
     * @openapi
     * @operation createTest
     * @summary Create test data
     * @description Creates test data with various property patterns
     * @tag Test
     * @security oauth2 write:test
     * @requestBody {description: "Test data to create", type: "TestAPI.TestRequest"}
     * @response 201 {description: "Test data created successfully", type: "TestAPI.TestResponse"}
     */
    @HttpPost
    global static TestResponse createTest(TestRequest request) {
        // Implementation...
    }
}
```

The system will automatically:
1. Extract schema definitions for `TestAPI.TestRequest` and `TestAPI.TestResponse`
2. Register these schemas in the central registry
3. Reference them with `$ref: "#/components/schemas/TestAPI.TestRequest"` in the OpenAPI output

## Handling Large Codebases

For extremely large APIs with many endpoints, you can split the documentation by API tag:

```apex
// Generate a separate specification for each API tag
OpenAPIParserModular.generateModularSpecifications();
```

This creates multiple Static Resources, one per API tag (e.g., `OPENAPI_ACCOUNT.json`, `OPENAPI_CONTACT.json`), and a master index (`OPENAPI_MASTER_INDEX.json`) that references all modules.

## Development

To work on this project in a scratch org:

1. [Set up CumulusCI](https://cumulusci.readthedocs.io/en/latest/tutorial.html)
2. Run `cci flow run dev_org --org dev` to deploy this project
3. Run `cci org browser dev` to open the org in your browser

## Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenAPI Initiative
- Salesforce Developer Community
- All our amazing contributors

---


