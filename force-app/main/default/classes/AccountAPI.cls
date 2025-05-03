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
     * @requestBody {description: "Account details", required: true, content: {application/json: {schema: {type: "object", properties: {Name: {type: "string"}, Industry: {type: "string"}, Phone: {type: "string"}}}}}}
     * @response 201 {description: "Account created successfully", type: "Account"}
     * @response 400 {description: "Invalid input"}
     */
    @HttpPost
    global static Account createAccount() {
        RestRequest req = RestContext.request;
        Account account = (Account)JSON.deserialize(req.requestBody.toString(), Account.class);
        
        try {
            insert account;
            RestContext.response.statusCode = 201;
            return account;
        } catch (Exception e) {
            RestContext.response.statusCode = 400;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation updateAccount
     * @summary Update an account
     * @description Updates an existing account record
     * @tag Account
     * @param id path string Account ID
     * @requestBody {description: "Updated account details", required: true, content: {application/json: {schema: {type: "object", properties: {Name: {type: "string"}, Industry: {type: "string"}, Phone: {type: "string"}}}}}}
     * @response 200 {description: "Account updated successfully", type: "Account"}
     * @response 404 {description: "Account not found"}
     */
    @HttpPut
    global static Account updateAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        Account account = (Account)JSON.deserialize(req.requestBody.toString(), Account.class);
        account.Id = accountId;
        
        try {
            update account;
            return account;
        } catch (Exception e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation deleteAccount
     * @summary Delete an account
     * @description Deletes an account record
     * @tag Account
     * @param id path string Account ID
     * @response 204 {description: "Account deleted successfully"}
     * @response 404 {description: "Account not found"}
     */
    @HttpDelete
    global static void deleteAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        try {
            delete [SELECT Id FROM Account WHERE Id = :accountId];
            RestContext.response.statusCode = 204;
        } catch (Exception e) {
            RestContext.response.statusCode = 404;
        }
    }
}