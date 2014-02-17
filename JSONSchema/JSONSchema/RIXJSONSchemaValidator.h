//
//  RIXJSONSchemaValidator.h
//  JSONSchema
//
//  Created by Ian Albert on 2014-01-23.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * The NSError domain for errors from RIXJSONSchemaValidator.
 */
extern NSString *const RIXJSONSchemaValidatorErrorDomain;

// NSError status codes for domain RIXJSONSchemaValidatorErrorDomain
enum {
    RIXJSONSchemaValidatorErrorUnknown,
    /**
     * A dictionary key was encountered that was not of type NSString.
     */
    RIXJSONSchemaValidatorErrorJSONIllegalKeyType,
    /**
     * A dictionary value or array element was encountered that was not of type
     * NSNumber, NSString, NSNull, NSArray or NSDictionary.
     */
    RIXJSONSchemaValidatorErrorJSONIllegalValueType,
    /**
     * A value was encountered that did not match the permitted types in the
     * schema.
     */
    RIXJSONSchemaValidatorErrorValueIncorrectType,
    RIXJSONSchemaValidatorErrorValueNotInEnum,
    /**
     * A numeric value did not validate against a "multipleOf" constraint.
     */
    RIXJSONSchemaValidatorErrorNumberNotAMultiple,
    RIXJSONSchemaValidatorErrorNumberBelowMinimum,
    RIXJSONSchemaValidatorErrorNumberAboveMaximum,
    RIXJSONSchemaValidatorErrorStringShorterThanMinimumLength,
    RIXJSONSchemaValidatorErrorStringLongerThanMaximumLength,
    RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern,
    RIXJSONSchemaValidatorErrorArrayTooFewElements,
    RIXJSONSchemaValidatorErrorArrayTooManyElements,
    RIXJSONSchemaValidatorErrorArrayElementsNotUnique,
    RIXJSONSchemaValidatorErrorArrayElementFailedSchema,
    RIXJSONSchemaValidatorErrorArrayAdditionalElementsInvalid,
    RIXJSONSchemaValidatorErrorObjectTooFewProperties,
    RIXJSONSchemaValidatorErrorObjectTooManyProperties,
    RIXJSONSchemaValidatorErrorObjectMissingRequiredProperty,
    RIXJSONSchemaValidatorErrorObjectFailedDependency,
    RIXJSONSchemaValidatorErrorObjectInvalidProperty,
    RIXJSONSchemaValidatorErrorValueFailedAllOf,
    RIXJSONSchemaValidatorErrorValueFailedAnyOf,
    RIXJSONSchemaValidatorErrorValueFailedOneOf,
    RIXJSONSchemaValidatorErrorValueFailedNot,
};

/**
 * Class for validating JSON values against a schema. Conforms to JSON Schema
 * internet draft v4.
 */
@interface RIXJSONSchemaValidator : NSObject

- (instancetype)init DEPRECATED_MSG_ATTRIBUTE("Use initWithSchema:");

- (instancetype)initWithSchema:(NSDictionary *)schema;

/**
 * Validates a JSON value and returns an array of NSError objects describing
 * each violation.
 */
- (NSArray *)validateJSONValue:(id)value;

@end

@protocol RIXJSONSchemaValidatorURIResolver <NSObject>

- (NSDictionary *)schemaForURI:(NSURL *)URI;

@end
