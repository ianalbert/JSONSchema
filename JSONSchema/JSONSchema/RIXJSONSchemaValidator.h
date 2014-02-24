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

/**
 * A userInfo key in an NSError of domain RIXJSONSchemaValidatorErrorDomain
 * which contains the JSON pointer of the element that failed validation.
 */
extern NSString *const RIXJSONSchemaValidatorErrorJSONPointerKey;

/**
 * A userInfo key in an NSError of domain RIXJSONSchemaValidatorErrorDomain
 * which contains an array of arrays of NSErrors (2D array). The elements in
 * the first array dimension represents the subschema that issued errors, while
 * the second array dimension represents individual errors in that subschema.
 */
extern NSString *const RIXJSONSchemaValidatorErrorSuberrorsKey;

// NSError status codes for domain RIXJSONSchemaValidatorErrorDomain
enum {
    /**
     * Unknown error code.
     */
    RIXJSONSchemaValidatorErrorUnknown = 0,
    /**
     * A dictionary key was encountered that was not of type NSString. This
     * indicates the dictionary being validated was not JSON.
     */
    RIXJSONSchemaValidatorErrorJSONIllegalKeyType = 0x0101,
    /**
     * A dictionary value or array element was encountered that was not of type
     * NSNumber, NSString, NSNull, NSArray or NSDictionary.
     */
    RIXJSONSchemaValidatorErrorJSONIllegalValueType,
    /**
     * A value was encountered that did not match one of the permitted types
     * in a "type" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.5.2
     */
    RIXJSONSchemaValidatorErrorValueIncorrectType = 0x1001,
    /**
     * A value was encountered that was not present in the list of allowed
     * values of an "enum" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.5.1
     */
    RIXJSONSchemaValidatorErrorValueNotInEnum,
    /**
     * A value was encountered that did not match a "format" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-7
     */
    RIXJSONSchemaValidatorErrorValueIncorrectFormat,
    /**
     * A value failed to validate against one or more schemas in an "allOf" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.5.3
     */
    RIXJSONSchemaValidatorErrorValueFailedAllOf,
    /**
     * A value failed to validate against any schemas in an "anyOf" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.5.4
     */
    RIXJSONSchemaValidatorErrorValueFailedAnyOf,
    /**
     * A value failed to validate against exactly one schema in a "oneOf" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.5.5
     */
    RIXJSONSchemaValidatorErrorValueFailedOneOf,
    /**
     * A value validated against a schema in a "not" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.5.6
     */
    RIXJSONSchemaValidatorErrorValueFailedNot,
    /**
     * A numeric value did not validate against a "multipleOf" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.1.1
     */
    RIXJSONSchemaValidatorErrorNumberNotAMultiple = 0x1101,
    /**
     * A numeric value was less than the value of a "minimum" rule; or less
     * than or equal to the value of a "minimum" rule if an "exclusiveMinimum"
     * rule was true.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.1.3
     */
    RIXJSONSchemaValidatorErrorNumberBelowMinimum,
    /**
     * A numeric value was greater than the value of a "maximum" rule; or
     * greater than or equal to the value of a "maximum" rule if an
     * "exclusiveMaximum" rule was true.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.1.2
     */
    RIXJSONSchemaValidatorErrorNumberAboveMaximum,
    /**
     * A string value was shorter than the length required by a "minLength" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.2.2
     */
    RIXJSONSchemaValidatorErrorStringShorterThanMinimumLength = 0x1201,
    /**
     * A string value was longer than the length required by a "maxLength" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.2.1
     */
    RIXJSONSchemaValidatorErrorStringLongerThanMaximumLength,
    /**
     * A string value did not match the regular expression in a "pattern" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.2.3
     */
    RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern,
    /**
     * An array value had fewer elements than the minimum specified by a
     * "minItems" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.3.3
     */
    RIXJSONSchemaValidatorErrorArrayTooFewElements = 0x1301,
    /**
     * An array value had more elements than the maximum specified by a
     * "maxItems" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.3.2
     */
    RIXJSONSchemaValidatorErrorArrayTooManyElements,
    /**
     * An array value contained non-unique elements with a "uniqueItems" rule
     * in effect.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.3.4
     */
    RIXJSONSchemaValidatorErrorArrayElementsNotUnique,
    /**
     * An array value contained elements forbidden by an "additionalItems" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.3.1
     */
    RIXJSONSchemaValidatorErrorArrayAdditionalElementsInvalid,
    /**
     * An object value contained fewer properties than the minimum specified by
     * a "minProperties" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.4.2
     */
    RIXJSONSchemaValidatorErrorObjectTooFewProperties = 0x1401,
    /**
     * An object value contained more properties than the maximum specified by
     * a "maxProperties" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.4.1
     */
    RIXJSONSchemaValidatorErrorObjectTooManyProperties,
    /**
     * An object value was missing a property list by a "required" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.4.3
     */
    RIXJSONSchemaValidatorErrorObjectMissingRequiredProperty,
    /**
     * An object value failed a dependency rule specified by a "dependencies"
     * rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#page-14
     */
    RIXJSONSchemaValidatorErrorObjectFailedDependency,
    /**
     * An object value contained a property forbidden by an
     * "additionalProperties" rule.
     * @see http://tools.ietf.org/html/draft-fge-json-schema-validation-00#section-5.4.4
     */
    RIXJSONSchemaValidatorErrorObjectInvalidProperty,
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
 * Protocol to allow loading of referenced external JSON Schemas. Custom URI
 * resolvers can be
 */
@protocol RIXJSONSchemaValidatorURIResolver <NSObject>

/**
 * Returns a JSON dictionary containing a JSON Schema at the given URI, or nil
 * if this resolver cannot locate the given URI.
 *
 * Implementations should test if they can handle the given URI. This may mean
 * checking the scheme of the URI, for example. If the resource cannot be
 * retrieved for any reason then the method should return nil.
 *
 * The URI is pre-normalized to point to the root of the schema. That is, the
 * fragment portion of the URI will always be "#", even if the reference that
 * initiated this schema retrieval pointed deeper within the schema.
 */
- (NSDictionary *)schemaForURI:(NSURL *)URI;

@end

/**
 * Class for validating JSON values against a schema. Conforms to JSON Schema
 * internet draft v4.
 */
@interface RIXJSONSchemaValidator : NSObject

/**
 * Disabled initializer. Use initWithSchema:.
 */
- (instancetype)init DEPRECATED_MSG_ATTRIBUTE("Use initWithSchema:");

/**
 * Creates a JSON Schema validator with the given JSON Schema. The schema must
 * be in the form of a JSON dictionary.
 */
- (instancetype)initWithSchema:(NSDictionary *)schema;

/**
 * Whether validation of "format" rules is performed. Default is YES.
 */
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

/**
 * Registers a custom URI resolver.
 */
- (void)addURIResolver:(id<RIXJSONSchemaValidatorURIResolver>)URIResolver;

@end

/**
 * A JSON Schema validator URI resolver for loading from an NSBundle. A
 * validator starts with one of these pre-registered to go off the main
 * bundle, however additional resolvers can be added to load from other bundles.
 */
@interface RIXJSONSchemaBundleURIResolver : NSObject <RIXJSONSchemaValidatorURIResolver>

/**
 * The bundle to load from. If nil then [NSBundle mainBundle] will be used.
 */
@property (nonatomic, strong) NSBundle *bundle;

/**
 * Creates a bundle URI resolver that uses [NSBundle mainBundle].
 */
- (instancetype)init;

/**
 * Creates a bundle URI resolver that uses the given bundle.
 */
- (instancetype)initWithBundle:(NSBundle *)bundle;

@end
