/**
 * @openapi
 * @title Contact Management API
 * @description API for managing Contact records
 * @version 1.0.0
 */
@RestResource(urlMapping='/contact/*')
global with sharing class ContactAPI {
    
    /**
     * @openapi
     * @operation getContact
     * @summary Get a contact by ID
     * @description Retrieves a contact record by its ID
     * @tag Contact
     * @param id path string Contact ID
     * @response 200 {description: "Contact retrieved successfully", type: "Contact"}
     * @response 404 {description: "Contact not found"}
     */
    @HttpGet
    global static Contact getContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        List<Contact> contacts = [SELECT Id, FirstName, LastName, Email, Phone FROM Contact WHERE Id = :contactId];
        if (contacts.isEmpty()) {
            RestContext.response.statusCode = 404;
            return null;
        }
        
        return contacts[0];
    }
    
    /**
     * @openapi
     * @operation createContact
     * @summary Create a new contact
     * @description Creates a new contact record
     * @tag Contact
     * @requestBody {description: "Contact details", required: true, content: {application/json: {schema: {type: "object", properties: {FirstName: {type: "string"}, LastName: {type: "string"}, Email: {type: "string"}, Phone: {type: "string"}}}}}}
     * @response 201 {description: "Contact created successfully", type: "Contact"}
     * @response 400 {description: "Invalid input"}
     */
    @HttpPost
    global static Contact createContact() {
        RestRequest req = RestContext.request;
        Contact contact = (Contact)JSON.deserialize(req.requestBody.toString(), Contact.class);
        
        try {
            insert contact;
            RestContext.response.statusCode = 201;
            return contact;
        } catch (Exception e) {
            RestContext.response.statusCode = 400;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation updateContact
     * @summary Update a contact
     * @description Updates an existing contact record
     * @tag Contact
     * @param id path string Contact ID
     * @requestBody {description: "Updated contact details", required: true, content: {application/json: {schema: {type: "object", properties: {FirstName: {type: "string"}, LastName: {type: "string"}, Email: {type: "string"}, Phone: {type: "string"}}}}}}
     * @response 200 {description: "Contact updated successfully", type: "Contact"}
     * @response 404 {description: "Contact not found"}
     */
    @HttpPut
    global static Contact updateContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        Contact contact = (Contact)JSON.deserialize(req.requestBody.toString(), Contact.class);
        contact.Id = contactId;
        
        try {
            update contact;
            return contact;
        } catch (Exception e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation deleteContact
     * @summary Delete a contact
     * @description Deletes a contact record
     * @tag Contact
     * @param id path string Contact ID
     * @response 204 {description: "Contact deleted successfully"}
     * @response 404 {description: "Contact not found"}
     */
    @HttpDelete
    global static void deleteContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        try {
            delete [SELECT Id FROM Contact WHERE Id = :contactId];
            RestContext.response.statusCode = 204;
        } catch (Exception e) {
            RestContext.response.statusCode = 404;
        }
    }
}