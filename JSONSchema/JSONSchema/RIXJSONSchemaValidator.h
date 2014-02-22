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
extern NSString *const RIXJSONSchemaValidatorErrorJSONPointerKey;

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
    RIXJSONSchemaValidatorErrorValueIncorrectFormat,
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
 * Protocol for adding support for custom "format" types. This allows validation
 * of special values too complex to specify with conventional schema rules alone,
 * such as special date formats, checksums, and other special considerations.
 */
@protocol RIXJSONSchemaFormatValidator <NSObject>

/**
 * Tests if the given JSON value is valid for the given format name. The
 * value will be of type NSNumber, NSString, NSNull, NSArray or NSDictionary.
 */
- (BOOL)isValidValue:(id)value
       forFormatName:(NSString *)formatName;

@end

/**
 * Class for validating JSON values against a schema. Conforms to JSON Schema
 * internet draft v4.
 */
@interface RIXJSONSchemaValidator : NSObject

- (instancetype)init DEPRECATED_MSG_ATTRIBUTE("Use initWithSchema:");

- (instancetype)initWithSchema:(NSDictionary *)schema;

@property (nonatomic, getter=isFormatValidationEnabled) BOOL formatValidationEnabled;

/**
 * Validates a JSON value and returns an array of NSError objects describing
 * each violation.
 */
- (NSArray *)validateJSONValue:(id)value;

/**
 * Registers a format validator for the given format name. If a schema has a
 * "format" property with the given formatName this validator will be invoked
 * to test if a value validates against it. If formatName is one of the
 * built-in formats ("date-time", "email", "hostname", "ipv4", "ipv6", "uri")
 * the given formatter will be used instead of the built-in one. Passing a
 * formatValidator of nil will remove a custom formatter for the given
 * formatName, restoring the default validator if it's a built-in format.
 */
- (void)setFormatValidator:(id<RIXJSONSchemaFormatValidator>)formatValidator
             forFormatName:(NSString *)formatName;

@end

@protocol RIXJSONSchemaValidatorURIResolver <NSObject>

- (NSDictionary *)schemaForURI:(NSURL *)URI;

@end
