import time
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

        self.logger.info("OpenAPI spec generation started (batch job running asynchronously)")


class RetrieveOpenAPISpec(BaseSalesforceApiTask):
    """Retrieves the generated OpenAPI specification static resource."""

    task_options = {
        "resource_name": {
            "description": "Name of the static resource to retrieve (default: OPENAPI_SPEC)",
            "required": False,
        },
        "output_file": {
            "description": "Full path to the output JSON file (default: force-app/main/default/staticresources/OPENAPI_SPEC.json). Can be overridden.",
            "required": False,
        },
        "max_wait": {
            "description": "Maximum seconds to wait for static resource to be created (default: 120)",
            "required": False,
        },
    }

    def _run_task(self):
        from cumulusci.tasks.salesforce import RetrieveUnpackaged
        from cumulusci.core.config import TaskConfig
        import tempfile
        import os
        import shutil
        
        resource_name = self.options.get("resource_name", "OPENAPI_SPEC")
        output_file = self.options.get("output_file", "force-app/main/default/staticresources/OPENAPI_SPEC.json")
        max_wait = int(self.options.get("max_wait", 120))
        wait_interval = 5
        
        # Extract directory from output_file for RetrieveUnpackaged
        output_dir = os.path.dirname(output_file)
        
        waited = 0
        package_xml_path = None
        
        try:
            # First check if resource already exists
            soql = f"SELECT Id, Name FROM StaticResource WHERE Name = '{resource_name}' LIMIT 1"
            query_result = self.sf.query(soql)
            
            if not query_result.get('records'):
                # Resource doesn't exist yet, wait for it
                self.logger.info(f"Static resource {resource_name} not found, waiting for it to be created...")
            
            while waited < max_wait:
                # Check if static resource exists
                soql = f"SELECT Id, Name FROM StaticResource WHERE Name = '{resource_name}' LIMIT 1"
                query_result = self.sf.query(soql)
                
                if query_result.get('records'):
                    # Resource exists, use CumulusCI's RetrieveUnpackaged task
                    self.logger.info(f"Static resource found, retrieving via Metadata API...")
                    
                    # Create package.xml content
                    package_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>{resource_name}</members>
        <name>StaticResource</name>
    </types>
    <version>63.0</version>
</Package>'''
                    
                    # Create temp file for package.xml
                    with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
                        f.write(package_xml)
                        package_xml_path = f.name
                    
                    # Create and run retrieve task
                    task_config = TaskConfig(
                        {
                            "class_path": "cumulusci.tasks.salesforce.RetrieveUnpackaged",
                            "options": {
                                "path": output_dir,
                                "package_xml": package_xml_path,
                            }
                        }
                    )
                    
                    retrieve_task = RetrieveUnpackaged(
                        self.project_config,
                        task_config,
                        org_config=self.org_config,
                    )
                    retrieve_task()
                    
                    # RetrieveUnpackaged extracts to a subdirectory structure
                    # Find the extracted resource file
                    extracted_resource_path = os.path.join(output_dir, "staticresources", f"{resource_name}.resource")
                    extracted_meta_path = os.path.join(output_dir, "staticresources", f"{resource_name}.resource-meta.xml")
                    package_xml_path = os.path.join(output_dir, "package.xml")
                    
                    # Move and rename the extracted file to the desired output location
                    if os.path.exists(extracted_resource_path):
                        # Ensure output directory exists
                        os.makedirs(os.path.dirname(output_file), exist_ok=True)
                        
                        # Copy the resource file to the output location
                        shutil.copy2(extracted_resource_path, output_file)
                        
                        # Clean up extracted files and package.xml
                        try:
                            os.unlink(extracted_resource_path)
                            if os.path.exists(extracted_meta_path):
                                os.unlink(extracted_meta_path)
                            # Remove package.xml if it exists
                            if os.path.exists(package_xml_path):
                                os.unlink(package_xml_path)
                            # Remove empty staticresources directory if it exists
                            extracted_dir = os.path.join(output_dir, "staticresources")
                            if os.path.exists(extracted_dir) and not os.listdir(extracted_dir):
                                os.rmdir(extracted_dir)
                        except Exception:
                            pass  # Ignore cleanup errors
                        
                        self.logger.info(f"Successfully retrieved {resource_name} to {output_file}")
                        return
                    else:
                        raise TaskOptionsError(
                            f"Retrieved resource file not found at expected path: {extracted_resource_path}"
                        )
                else:
                    # Resource not ready yet, continue waiting
                    if waited < max_wait:
                        time.sleep(wait_interval)
                        waited += wait_interval
                        self.logger.debug(f"Waiting for static resource... ({waited}s/{max_wait}s)")
            
            raise TaskOptionsError(
                f"Timeout: Static resource {resource_name} was not created within {max_wait} seconds"
            )
        finally:
            # Clean up temp file
            if package_xml_path and os.path.exists(package_xml_path):
                try:
                    os.unlink(package_xml_path)
                except Exception:
                    pass  # Ignore cleanup errors 