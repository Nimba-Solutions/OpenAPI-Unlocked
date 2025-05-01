# Metadata Rules

## Flow Rules
| Rule Name | Message/Description |
|-----------|-------------------|
| DMLStatementInFlowLoop | DML Operations shouldn't be done inside of Flow loops |

## Permission Rules
| Rule Name | Message/Description |
|-----------|-------------------|
| ViewSetupByNonSysAdmins | Exposing the setup menu to non-authorized users. |

## Permission Sets
| Rule Name | Message/Description |
|-----------|-------------------|
| PermissionSetRequiresDescription | Permission Sets should have a description |

## Objects
| Rule Name | Message/Description |
|-----------|-------------------|
| CustomObjectRequiresDescription | Custom objects (__c) should have a description |

## Fields
| Rule Name | Message/Description |
|-----------|-------------------|
| CustomFieldRequiresDescription | Custom fields should have a description |
| NoUnderscoresInFieldNames | Custom field name should not contain underscores. |
| NoFieldPermissionsInProfile | Field permissions should not be included in profile metadata. |
| NoObjectPermissionsInProfile | Object permissions should not be included in profile metadata. |

## Field Naming Conventions
| Rule Name | Required Pattern |
|-----------|-----------------|
| CheckboxFieldNamingConvention | PascalCaseBool__c |
| TextAreaFieldNamingConvention | PascalCaseTxt__c |
| RichTextFieldNamingConvention | PascalCaseTxt__c |
| LongTextAreaFieldNamingConvention | PascalCaseTxt__c |
| NumberFieldNamingConvention | PascalCaseNumber__c |
| DateFieldNamingConvention | PascalCaseDate__c |
| LookupFieldNamingConvention | PascalCaseId__c |
| MasterDetailFieldNamingConvention | PascalCaseId__c |
| DateTimeFieldNamingConvention | PascalCaseDateTime__c |
| UrlFieldNamingConvention | PascalCaseUrl__c |
| PicklistFieldNamingConvention | PascalCasePk__c |
| MultiSelectPicklistFieldNamingConvention | PascalCasePk__c |
| CurrencyFieldNamingConvention | PascalCaseCurrency__c |
| PercentFieldNamingConvention | PascalCasePercent__c |
