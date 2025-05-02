# OpenAPI Unlocked

OpenAPI Unlocked brings the power of OpenAPI (Swagger) documentation to Salesforce development through an unlocked package. Enable your team to create beautiful, interactive API documentation with minimal effort - directly on Salesforce!

## Overview

OpenAPI Unlocked allows Salesforce developers to add simple annotations to their Apex classes that automatically generate standardized OpenAPI (Swagger) documentation. Publish your API documentation directly to Experience Cloud sites and give your integration partners the gift of clear, interactive documentation.

## Key Features

- **Reduce Integration Friction**: Clear documentation means faster partner onboarding and fewer support tickets
- **Stay in Sync**: Documentation is generated directly from your code, so it's always up-to-date
- **Developer Friendly**: Simple annotations that feel familiar to Java developers
- **Experience Cloud Ready**: Publish beautiful, interactive API documentation to your Experience Cloud sites
- **100% Native**: Built as a Salesforce unlocked package with no external dependencies

## Basic Usage

### 1. Add Swagger annotations to your Apex classes:

```apex
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
```
> [!TIP]
> Some annotations (such as `@response` and `@requestBody`) support sObjects and Apex-Defined types. (More examples coming soon)

### 2. Run `OpenAPIParser.parseClasses()` 

### 3. Download the resulting `OPENAPI_SPEC.json` from your Org's Static Resources

### 4. Upload `OPENAPI_SPEC.json` into your preferred tooling (e.g. Postman, SwaggerUI)
![image](https://github.com/user-attachments/assets/65422716-e39b-42df-af07-5f1f7edce6c1)


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


