from cumulusci.core.exceptions import TaskOptionsError
from cumulusci.tasks.salesforce import BaseSalesforceApiTask
from cumulusci.utils import inject_namespace

class GenerateOpenAPISpec(BaseSalesforceApiTask):
    """Generates OpenAPI specification from Apex classes."""

    task_options = {
        "version": {
            "description": "Version number for the OpenAPI spec",
            "required": False,
        },
        "title": {
            "description": "Title for the OpenAPI spec",
            "required": False,
        },
        "description": {
            "description": "Description for the OpenAPI spec",
            "required": False,
        },
    }

    def _run_task(self):
        # Get the version from options or project config
        version = self.options.get("version")
        if not version:
            version = self.project_config.project__package__version
            if not version:
                version = "1.0.0"  # Fallback default

        # Prepare the Apex code to call parseClasses directly
        apex = "OpenAPIParser.parseClasses();"

        # Execute the anonymous Apex
        self.logger.info(f"Generating OpenAPI spec with version {version}")
        result = self.tooling._call_salesforce(
            method="GET",
            url=f"{self.tooling.base_url}executeAnonymous",
            params={"anonymousBody": apex},
        )

        # Check the result
        anon_results = result.json()
        if not anon_results["compiled"]:
            raise TaskOptionsError(
                f"Compilation error: {anon_results['compileProblem']} at line {anon_results['line']}"
            )
        if not anon_results["success"]:
            raise TaskOptionsError(
                f"Execution error: {anon_results['exceptionMessage']}\n{anon_results['exceptionStackTrace']}"
            )

        self.logger.info("OpenAPI spec generated successfully") 