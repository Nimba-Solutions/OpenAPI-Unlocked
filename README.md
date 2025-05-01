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

Add Swagger annotations to your Apex classes:

```apex
@RestResource(urlMapping='/api/v1/accounts/*')
global with sharing class AccountAPI {
    
    @HttpGet
    @Swagger(
        summary='Get Account Details',
        description='Retrieves account information by ID',
        responses={
            @SwaggerResponse(code=200, description='Success'),
            @SwaggerResponse(code=404, description='Account not found')
        }
    )
    global static Account getAccount() {
        // Your implementation here
    }
}
```

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

## Support

- Documentation: [OpenAPI Unlocked Documentation](https://docs.swaggerunlocked.com)
- Issues: [GitHub Issues](https://github.com/yourusername/swagger-unlocked/issues)
- Questions: [Stack Exchange](https://salesforce.stackexchange.com/questions/tagged/swagger-unlocked)

## Acknowledgments

- OpenAPI Initiative
- Salesforce Developer Community
- All our amazing contributors

---


