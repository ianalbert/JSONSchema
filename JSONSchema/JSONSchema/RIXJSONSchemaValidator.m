//
//  RIXJSONSchemaValidator.m
//  JSONSchema
//
//  Created by Ian Albert on 2014-01-23.
//  Copyright (c) 2014 Ian Albert. All rights reserved.
//

#import "RIXJSONSchemaValidator.h"

NSString *const RIXJSONSchemaValidatorErrorDomain = @"RIXJSONSchemaValidatorError";

typedef NS_ENUM(NSUInteger, RIXJSONDataType) {
    RIXJSONDataTypeUnknown = 0,

    RIXJSONDataTypeNull = (1 << 0),
    RIXJSONDataTypeBoolean = (1 << 1),
    RIXJSONDataTypeInteger = (1 << 2),
    RIXJSONDataTypeNumber = (1 << 3),
    RIXJSONDataTypeString = (1 << 4),
    RIXJSONDataTypeArray = (1 << 5),
    RIXJSONDataTypeObject = (1 << 6),

    RIXJSONDataTypeMaskAll = RIXJSONDataTypeNull | RIXJSONDataTypeBoolean | RIXJSONDataTypeInteger | RIXJSONDataTypeNumber | RIXJSONDataTypeString | RIXJSONDataTypeArray | RIXJSONDataTypeObject,
};

#define keyMainID @"id"
#define keyMainSchema @"$schema"
#define keyMainDefinitions @"definitions"
#define keyMainRef @"$ref"

#define keyNumberMultipleOf @"multipleOf"
#define keyNumberMinimum @"minimum"
#define keyNumberMaximum @"maximum"
#define keyNumberExclusiveMinimum @"exclusiveMinimum"
#define keyNumberExclusiveMaximum @"exclusiveMaximum"

#define keyStringMinLength @"minLength"
#define keyStringMaxLength @"maxLength"
#define keyStringPattern @"pattern"

#define keyArrayItems @"items"
#define keyArrayAdditionalItems @"additionalItems"
#define keyArrayMinItems @"minItems"
#define keyArrayMaxItems @"maxItems"
#define keyArrayUniqueItems @"uniqueItems"

#define keyObjectProperties @"properties"
#define keyObjectPatternProperties @"patternProperties"
#define keyObjectAdditionalProperties @"additionalProperties"
#define keyObjectDependencies @"dependencies"
#define keyObjectRequired @"required"
#define keyObjectMinProperties @"minProperties"
#define keyObjectMaxProperties @"maxProperties"

#define keyAnyEnum @"enum"
#define keyAnyType @"type"
#define keyAnyAllOf @"allOf"
#define keyAnyAnyOf @"anyOf"
#define keyAnyOneOf @"oneOf"
#define keyAnyNot @"not"
#define keyAnyFormat @"format"

#define keyMetaTitle @"title"
#define keyMetaDescription @"description"
#define keyMetaDefault @"default"

#define valueDatatypeArray @"array"
#define valueDatatypeBoolean @"boolean"
#define valueDatatypeInteger @"integer"
#define valueDatatypeNumber @"number"
#define valueDatatypeNull @"null"
#define valueDatatypeObject @"object"
#define valueDatatypeString @"string"

#define valueFormatDateTime @"date-time"
#define valueFormatEmail @"email"
#define valueFormatHostname @"hostname"
#define valueFormatIPV4 @"ipv4"
#define valueFormatIPV6 @"ipv6"
#define valueFormatURI @"uri"

@class RIXJSONSchemaValidatorSchema;

@interface RIXJSONSchemaValidator ()

@property (nonatomic, strong) RIXJSONSchemaValidatorSchema *rootSchema;
@property (nonatomic, strong) NSMutableDictionary *patternToRegex; // NSString -> NSRegularExpression
@property (nonatomic, strong) NSMutableDictionary *URIToSchema; // NSURL -> RIXJSONSchemaValidatorSchema
@property (nonatomic, strong) NSMutableArray *URIResolvers; // id<RIXJSONSchemaValidatorURIResolver>[]

- (RIXJSONSchemaValidatorSchema *)schemaForURI:(NSURL *)URI;

@end

@implementation NSNull (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeNull;
}
@end

@implementation NSNumber (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    static char const *boolTypes = "BcC";
    static char const *intTypes = "ilqcsILQCS";
    const char *selfType = [self objCType];
    if ((strstr(boolTypes, selfType) != NULL) && ([self integerValue] == 0 || [self integerValue] == 1)) {
        return RIXJSONDataTypeBoolean;
    }
    if (strstr(intTypes, selfType) != NULL) {
        return RIXJSONDataTypeInteger | RIXJSONDataTypeNumber;
    }
    return RIXJSONDataTypeNumber;
}
@end

@implementation NSString (RIXJSONSchemaValidator)
- (BOOL)containsNonNegativeInteger
{
    NSUInteger len = self.length;
    if (len == 0) {
        return NO;
    }
    for (NSUInteger i = 0; i < len; i++) {
        unichar ch = [self characterAtIndex:i];
        if (ch < '0' || ch > '9') {
            return NO;
        }
    }
    return YES;
}
- (NSUInteger)unsignedIntegerValueOrDefault:(NSUInteger)fallback
{
    NSUInteger len = self.length;
    if (len == 0) {
        return fallback;
    }
    NSUInteger value = 0;
    for (NSUInteger i = 0; i < len; i++) {
        unichar ch = [self characterAtIndex:i];
        if (ch < '0' || ch > '9') {
            return fallback;
        }
        NSUInteger d = (ch - '0');
        value = (value * 10) + d;
    }
    return value;
}
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeString;
}
@end

@implementation NSDictionary (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeObject;
}
- (id)objectAtJSONPointerSegment:(NSString *)segment
{
    return [self objectForKey:segment];
}
@end

@implementation NSArray (RIXJSONSchemaValidator)
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeArray;
}
- (id)objectAtJSONPointerSegment:(NSString *)segment
{
    NSUInteger index = [segment unsignedIntegerValueOrDefault:-1];
    if (index >= self.count) {
        return nil;
    }
    return [self objectAtIndex:index];
}
@end

@implementation NSObject (RIXJSONSchemaValidator)
- (id)objectAtJSONPointerSegment:(NSString *)segment
{
    return nil;
}
- (id)objectAtJSONPointer:(NSString *)JSONPointer
{
    NSUInteger len = [JSONPointer length];
    if (len == 0) {
        // Empty string = root node
        return self;
    }
    if ([JSONPointer characterAtIndex:0] != '/') {
        // Invalid pointer. Must be absolute and begin with a /, unless the empty string
        return nil;
    }
    id node = self;
    NSUInteger segmentStart = 1; // skip initial slash
    BOOL segmentNeedsEscape = NO;
    for (NSUInteger i = segmentStart; i < len; i++) {
        unichar ch = [JSONPointer characterAtIndex:i];
        if (ch == '/') {
            NSString *segment = [JSONPointer substringWithRange:NSMakeRange(segmentStart, i - segmentStart)];
            if (segmentNeedsEscape) {
                segment = [segment stringByReplacingOccurrencesOfString:@"~1" withString:@"/"];
                segment = [segment stringByReplacingOccurrencesOfString:@"~0" withString:@"~"];
            }
            node = [node objectAtJSONPointerSegment:segment];
            if (!node) {
                return nil;
            }
            segmentStart = i + 1;
            segmentNeedsEscape = NO;
        }
        else {
            if (ch == '~') {
                if (i + 1 >= len) {
                    // Truncated escape sequence
                    return nil;
                }
                unichar next = [JSONPointer characterAtIndex:i + 1];
                if (next != '0' && next != '1') {
                    // Illegal escape sequence
                    return nil;
                }
                segmentNeedsEscape = YES;
            }
        }
    }
    NSString *segment = [JSONPointer substringWithRange:NSMakeRange(segmentStart, len - segmentStart)];
    if (segmentNeedsEscape) {
        segment = [segment stringByReplacingOccurrencesOfString:@"~1" withString:@"/"];
        segment = [segment stringByReplacingOccurrencesOfString:@"~0" withString:@"~"];
    }
    node = [node objectAtJSONPointerSegment:segment];
    return node;
}
- (RIXJSONDataType)JSONDataType
{
    return RIXJSONDataTypeUnknown;
}
@end

@implementation NSURL (RIXJSONSchemaValidator)
- (NSString *)absoluteStringWithoutFragment
{
    NSString *str = self.absoluteString;
    NSRange hash = [str rangeOfString:@"#"];
    if (hash.location == NSNotFound) {
        return str;
    }
    return [str substringToIndex:hash.location];
}
+ (NSURL *)defaultRootJSONSchemaURI
{
    NSURL *URL = [[NSURL alloc] initWithString:@"#"];
    return URL;
}
- (NSURL *)normalizedRootJSONSchemaURI
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:YES];
    if ([components.fragment isEqualToString:@""]) {
        return self;
    }
    components.fragment = @"";
    return components.URL;
}
- (NSString *)JSONPointer
{
    NSString *fragment = self.fragment;
    if (fragment.length == 0) {
        return @"";
    }
    if (![fragment hasPrefix:@"/"]) {
        NSString *ret = [@"/" stringByAppendingString:fragment];
        return ret;
    }
    return fragment;
}
- (NSURL *)URIRelativeToJSONReference:(NSString *)ref
{
    NSString *preNoFragment = [self absoluteStringWithoutFragment];
    NSURL *newURL = [[NSURL alloc] initWithString:ref relativeToURL:self];
    NSString *postNoFragment = [newURL absoluteStringWithoutFragment];
    if (![postNoFragment isEqual:preNoFragment]) {
        // URL changed. Fragment is replaced.
        return newURL;
    }
    // Same base URL. Resolve fragment.
    NSURLComponents *oldComponents = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:YES];
    NSURLComponents *newComponents = [[NSURLComponents alloc] initWithURL:newURL resolvingAgainstBaseURL:YES];
    if (oldComponents.fragment.length > 0) {
        if (newComponents.fragment) {
            if (![newComponents.fragment hasPrefix:@"/"]) {
                // New fragment is relative. Resolve against old fragment
                // "/", "foo/bar" -> "//foo/bar"
                // "blah", "bloo"
                if (![oldComponents.fragment hasPrefix:@"/"]) {
                    // E.g. old = #foo, new = #bar -> #/foo/bar
                    newComponents.fragment = [NSString stringWithFormat:@"/%@/%@", oldComponents.fragment, newComponents.fragment];
                }
                else {
                    // E.g. old = #/foo, new = #bar -> #/foo/bar
                    newComponents.fragment = [NSString stringWithFormat:@"%@/%@", oldComponents.fragment, newComponents.fragment];
                }
            }
            // else new ref was absolute, so leave it replacing the old fragment
        }
        else {
            // New ref didn't include a fragment, so default to root
            newComponents.fragment = @"";
        }
    }
    else if (!newComponents.fragment) {
        // No fragment. Default to root.
        newComponents.fragment = @"";
    }
    if (newComponents.fragment.length > 0 && ![newComponents.fragment hasPrefix:@"/"]) {
        newComponents.fragment = [@"/" stringByAppendingString:newComponents.fragment];
    }
    NSURL *URL = newComponents.URL;
    return URL;
}
@end

@interface RIXJSONSchemaValidatorSchema : NSObject
@property (nonatomic, weak) RIXJSONSchemaValidator *validator;
@property (nonatomic, strong) NSURL *URI;
@property (nonatomic, strong) NSDictionary *schema;
@property (nonatomic, strong) RIXJSONSchemaValidatorSchema *nextSchema;
@end



@implementation RIXJSONSchemaValidatorSchema
- (instancetype)initWithSchema:(NSDictionary *)schema
                           URI:(NSURL *)URI
                     validator:(RIXJSONSchemaValidator *)validator
{
    self = [super init];
    if (self) {
        _schema = schema;
        _URI = URI;
        _validator = validator;
    }
    return self;
}
- (id)objectForKeyedSubscript:(id)key
{
    id val = _schema[key];
    if (val) {
        // Value was in this schema
        return val;
    }
    if (_nextSchema) {
        // Value was in the next schema (or somewhere down the chain)
        return _nextSchema[key];
    }
    id ref = _schema[keyMainRef];
    if (ref) {
        NSURL *nextURI = [_URI URIRelativeToJSONReference:ref];
        _nextSchema = [_validator schemaForURI:nextURI];
        return _nextSchema[key];
    }
    return nil;
}
- (RIXJSONSchemaValidatorSchema *)schemaAtJSONPointer:(NSString *)JSONPointer
{
    id elem = [_schema objectAtJSONPointer:JSONPointer];
    if ([elem JSONDataType] != RIXJSONDataTypeObject) {
        return nil;
    }
    if (elem == _schema) {
        return self;
    }
    NSURL *subURI = [_URI URIRelativeToJSONReference:[@"#" stringByAppendingString:JSONPointer]];
    RIXJSONSchemaValidatorSchema *subschema = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:elem URI:subURI validator:_validator];
    return subschema;
}
@end

@interface RIXJSONSchemaValidatorContext : NSObject
@property (nonatomic, weak) RIXJSONSchemaValidator *validator;
@property (nonatomic, strong) NSMutableArray *errors;
@property (nonatomic, strong) NSMutableArray *schemaStack; // RIXJSONSchemaValidatorSchema[]
@end
@implementation RIXJSONSchemaValidatorContext

- (instancetype)initWithInitialSchema:(RIXJSONSchemaValidatorSchema *)schema
                            validator:(RIXJSONSchemaValidator *)validator
{
    self = [super init];
    if (self) {
        _schemaStack = [[NSMutableArray alloc] initWithObjects:schema, nil];
        _validator = validator;
    }
    return self;
}

- (void)addErrorCode:(NSInteger)errorCode
             message:(NSString *)pattern, ...
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    if (pattern) {
        va_list args;
        va_start(args, pattern);
        NSString *message = [[NSString alloc] initWithFormat:pattern arguments:args];
        va_end(args);
        userInfo[NSLocalizedDescriptionKey] = message;
    }
    NSError *error = [NSError errorWithDomain:RIXJSONSchemaValidatorErrorDomain code:errorCode userInfo:userInfo];
    if (!self.errors) {
        self.errors = [[NSMutableArray alloc] init];
    }
    [self.errors addObject:error];
    [self.errors objectAtIndexedSubscript:0];
}

- (id)objectForKeyedSubscript:(id)key
{
    NSDictionary *schema = [self.schemaStack lastObject];
    return schema[key];
}

- (BOOL)boolForKey:(id)key orDefault:(BOOL)undefinedValue
{
    id elem = self[key];
    return ([elem isKindOfClass:[NSNumber class]]) ? [elem boolValue] : undefinedValue;
}

- (NSUInteger)allowedDataTypes
{
    id elem = self[keyAnyType];
    if (!elem) {
        return RIXJSONDataTypeMaskAll;
    }
    NSArray *types;
    if ([elem JSONDataType] == RIXJSONDataTypeString) {
        types = @[ elem ];
    }
    else if ([elem JSONDataType] == RIXJSONDataTypeArray) {
        types = elem;
    }
    else {
        return RIXJSONDataTypeMaskAll;
    }
    NSUInteger typeMask = 0;
    for (id v in types) {
        if ([v isEqual:valueDatatypeArray]) {
            typeMask |= RIXJSONDataTypeArray;
        }
        else if ([v isEqual:valueDatatypeBoolean]) {
            typeMask |= RIXJSONDataTypeBoolean;
        }
        else if ([v isEqual:valueDatatypeInteger]) {
            typeMask |= RIXJSONDataTypeInteger;
        }
        else if ([v isEqual:valueDatatypeNull]) {
            typeMask |= RIXJSONDataTypeNull;
        }
        else if ([v isEqual:valueDatatypeNumber]) {
            typeMask |= RIXJSONDataTypeNumber;
        }
        else if ([v isEqual:valueDatatypeObject]) {
            typeMask |= RIXJSONDataTypeObject;
        }
        else if ([v isEqual:valueDatatypeString]) {
            typeMask |= RIXJSONDataTypeString;
        }
    }
    return typeMask;
}

- (void)pushSchema:(NSDictionary *)schema pathComponent:(id)pathComponent
{
    if (!_schemaStack) {
        _schemaStack = [[NSMutableArray alloc] init];
    }
    RIXJSONSchemaValidatorSchema *topSchema = [_schemaStack lastObject];
    NSURL *URI = [topSchema.URI URIRelativeToJSONReference:[NSString stringWithFormat:@"#%@", pathComponent]];
    RIXJSONSchemaValidatorSchema *schemaObj = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:schema URI:URI validator:_validator];
    [_schemaStack addObject:schemaObj];
}

- (void)pop
{
    [_schemaStack removeLastObject];
}

@end

@implementation RIXJSONSchemaValidator

- (instancetype)init
{
    return nil;
}

// public
- (instancetype)initWithSchema:(NSDictionary *)schema
{
    self = [super init];
    if (self) {
        if (!schema) {
            return nil;
        }
        NSDictionary *schemaDictCopy = [schema copy];
        _URIToSchema = [[NSMutableDictionary alloc] init];
        NSString *ident = schema[keyMainID];
        NSURL *URI = nil;
        if (ident) {
            URI = [[[NSURL alloc] initWithString:ident] normalizedRootJSONSchemaURI];
        }
        if (!URI) {
            URI = [NSURL defaultRootJSONSchemaURI];
        }
        _rootSchema = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:schemaDictCopy URI:URI validator:self];
        _URIToSchema[URI] = _rootSchema;
    }
    return self;
}

// public
- (NSArray *)validateJSONValue:(id)value
{
    RIXJSONSchemaValidatorContext *context = [[RIXJSONSchemaValidatorContext alloc] initWithInitialSchema:_rootSchema validator:self];
    [self validateJSONValue:value context:context];
    [context pop];
    return context.errors;
}

- (void)validateJSONValue:(id)value
                  context:(RIXJSONSchemaValidatorContext *)context
{
    NSUInteger possibleDataTypes = [value JSONDataType];
    if (possibleDataTypes == RIXJSONDataTypeUnknown) {
        [context addErrorCode:RIXJSONSchemaValidatorErrorJSONIllegalValueType message:@"Value not a legal JSON value class (%@)", [value class]];
        return;
    }
    NSUInteger allowedDataTypes = [context allowedDataTypes];
    NSUInteger commonDataTypes = possibleDataTypes & allowedDataTypes;
    if (commonDataTypes == 0) {
#warning TODO: Add details to message
        [context addErrorCode:RIXJSONSchemaValidatorErrorValueIncorrectType message:@"Value type does not match schema"];
    }
    if (commonDataTypes & (RIXJSONDataTypeNull | RIXJSONDataTypeBoolean)) {
        // Type is correct. Nothing more to validate.
    }
    else if (commonDataTypes & RIXJSONDataTypeObject) {
        [self validateJSONObject:value context:context];
    }
    else if (commonDataTypes & RIXJSONDataTypeArray) {
        [self validateJSONArray:value context:context];
    }
    else if (commonDataTypes & RIXJSONDataTypeString) {
        [self validateJSONString:value context:context];
    }
    else if (commonDataTypes & (RIXJSONDataTypeInteger | RIXJSONDataTypeNumber)) {
        [self validateJSONNumber:value context:context];
    }
}

- (void)validateJSONObject:(NSDictionary *)object
                   context:(RIXJSONSchemaValidatorContext *)context
{
    NSNumber *minProperties = context[keyObjectMinProperties];
    if (minProperties) {
        if (object.count < [minProperties integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorObjectTooFewProperties message:@"Object must have at least %i properties", [minProperties integerValue]];
        }
    }

    NSNumber *maxProperties = context[keyObjectMaxProperties];
    if (maxProperties) {
        if (object.count > [maxProperties integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorObjectTooManyProperties message:@"Object must have no more than %i properties", [maxProperties integerValue]];
        }
    }

    NSArray *required = context[keyObjectRequired];
    if (required) {
        for (NSString *key in required) {
            if (!object[key]) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorObjectMissingRequiredProperty message:@"Object must contain value for property \"%@\"", key];
            }
        }
    }

    NSDictionary *properties = context[keyObjectProperties];
    NSDictionary *patternProperties = context[keyObjectPatternProperties];
    id additionalProperties = context[keyObjectAdditionalProperties];
    [object enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, id propertyValue, BOOL *stop) {
        __block BOOL schemaFound = NO;
        NSDictionary *itemSchema = properties[propertyName];
        if (itemSchema) {
            [context pushSchema:itemSchema pathComponent:propertyName];
            [self validateJSONValue:propertyValue context:context];
            [context pop];
            schemaFound = YES;
        }
        else {
            [patternProperties enumerateKeysAndObjectsUsingBlock:^(NSString *pattern, NSDictionary *itemSchema, BOOL *stop) {
                if ([self doesString:propertyName matchPattern:pattern]) {
                    [context pushSchema:itemSchema pathComponent:propertyName];
                    [self validateJSONValue:propertyValue context:context];
                    [context pop];
                    schemaFound = YES;
                    // NOTE: Not breaking out of loop. It's possible for
                    // propertyName to match multiple patternProperties. The
                    // draft does not prescribe a proper way of handling this
                    // situation, so I'm choosing to validate against all
                    // matching schemas.
                }
            }];
        }
        if (!schemaFound) {
            if (additionalProperties) {
                if ([additionalProperties isKindOfClass:[NSNumber class]]) {
                    if ([additionalProperties boolValue]) {
                        // Additional properties are allowed but hae no schema
                    }
                    else {
                        // Additional properties are not allowed
                        [context addErrorCode:RIXJSONSchemaValidatorErrorObjectInvalidProperty message:@"Property \"%@\" not allowed", propertyName];
                    }
                }
                else if ([additionalProperties isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *itemSchema = additionalProperties;
                    [context pushSchema:itemSchema pathComponent:propertyName];
                    [self validateJSONValue:propertyValue context:context];
                    [context pop];
                }
            }
        }
    }];
#warning TODO: dependencies
}

- (void)validateJSONArray:(NSArray *)array
                  context:(RIXJSONSchemaValidatorContext *)context
{
    NSNumber *minItems = context[keyArrayMinItems];
    if (minItems) {
        if (array.count < [minItems integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayTooFewElements message:@"Array must have at least %i elements", [minItems integerValue]];
        }
    }

    NSNumber *maxItems = context[keyArrayMaxItems];
    if (maxItems) {
        if (array.count > [maxItems integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayTooManyElements message:@"Array must have no more than %i elements", [maxItems integerValue]];
        }
    }

    BOOL uniqueItems = [context boolForKey:keyArrayUniqueItems orDefault:NO];
    if (uniqueItems) {
        NSMutableSet *set = [[NSMutableSet alloc] initWithArray:array];
        if (set.count != array.count) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayElementsNotUnique message:@"Array elements must be unique"];
        }
    }

    id items = context[keyArrayItems];
    NSDictionary *singleItemSchema = ([items isKindOfClass:[NSDictionary class]]) ? items : nil;
    NSArray *multipleItemSchemas = ([items isKindOfClass:[NSArray class]]) ? items : nil;
    id additionalItems = context[keyArrayAdditionalItems];
    BOOL allowAdditionalItems = (![additionalItems isKindOfClass:[NSNumber class]] || [additionalItems boolValue]);
    NSDictionary *additionalItemSchema = ([additionalItems isKindOfClass:[NSDictionary class]]) ? additionalItems : nil;
    [array enumerateObjectsUsingBlock:^(id element, NSUInteger index, BOOL *stop) {
        if (singleItemSchema) {
            [context pushSchema:singleItemSchema pathComponent:@(index)];
            [self validateJSONValue:element context:context];
            [context pop];
        }
        else if (multipleItemSchemas && index < multipleItemSchemas.count) {
            [context pushSchema:multipleItemSchemas[index] pathComponent:@(index)];
            [self validateJSONValue:element context:context];
            [context pop];
        }
        else if (allowAdditionalItems) {
            if (additionalItemSchema) {
                [context pushSchema:additionalItemSchema pathComponent:@(index)];
                [self validateJSONValue:element context:context];
                [context pop];
            }
        }
        else {
            [context addErrorCode:RIXJSONSchemaValidatorErrorArrayAdditionalElementsInvalid message:@"Additional array elements not permitted"];
        }
    }];
}

- (void)validateJSONNumber:(NSNumber *)number
                   context:(RIXJSONSchemaValidatorContext *)context
{
    double val = [number doubleValue];
    NSNumber *multipleOf = context[keyNumberMultipleOf];
    if (multipleOf) {
        double mult = [multipleOf doubleValue];
        double mod = fmod(val, mult);
#warning TODO: Figure out best way to do fuzzy float compare
        if (mod != 0.0) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorNumberNotAMultiple message:@"%f is not a multiple of %f", val, mult];
        }
    }

    NSNumber *minimum = context[keyNumberMinimum];
    BOOL exclusiveMinimum = [context boolForKey:keyNumberExclusiveMinimum orDefault:NO];
    if (minimum) {
        double min = [minimum doubleValue];
        if (exclusiveMinimum) {
            if (val <= min) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberBelowMinimum message:@"%f must be greater than %f", val, min];
            }
        }
        else {
            if (val < min) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberBelowMinimum message:@"%f must be greater than or equal to %f", val, min];
            }
        }
    }

    NSNumber *maximum = context[keyNumberMaximum];
    BOOL exclusiveMaximum = [context boolForKey:keyNumberExclusiveMaximum orDefault:NO];
    if (maximum) {
        double max = [maximum doubleValue];
        if (exclusiveMaximum) {
            if (val >= max) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberAboveMaximum message:@"%f must be less than %f", val, max];
            }
        }
        else {
            if (val > max) {
                [context addErrorCode:RIXJSONSchemaValidatorErrorNumberAboveMaximum message:@"%f must be less than or equal to %f", val, max];
            }
        }
    }
}

- (void)validateJSONString:(NSString *)string
                   context:(RIXJSONSchemaValidatorContext *)context
{
    NSNumber *minLength = context[keyStringMinLength];
    if (minLength) {
        if (string.length < [minLength integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorStringShorterThanMinimumLength message:@"String must be at least %i characters", [minLength integerValue]];
        }
    }

    NSNumber *maxLength = context[keyStringMaxLength];
    if (maxLength) {
        if (string.length > [maxLength integerValue]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorStringLongerThanMaximumLength message:@"String must be no more than %i characters", [maxLength integerValue]];
        }
    }

    NSString *pattern = context[keyStringPattern];
    if (pattern) {
        if ([self doesString:string matchPattern:pattern]) {
            [context addErrorCode:RIXJSONSchemaValidatorErrorStringDoesNotMatchPattern message:@"String does not match regular expression \"%@\"", pattern];
        }
    }
}

- (RIXJSONSchemaValidatorSchema *)schemaForURI:(NSURL *)URI
{
    NSURL *rootURI = [URI normalizedRootJSONSchemaURI];
    RIXJSONSchemaValidatorSchema *schema = _URIToSchema[rootURI];
    if (schema) {
        RIXJSONSchemaValidatorSchema *retVal = [schema schemaAtJSONPointer:[URI JSONPointer]];
        return retVal;
    }
    for (id<RIXJSONSchemaValidatorURIResolver> URIResolver in _URIResolvers) {
        NSDictionary *schemaJSON = [URIResolver schemaForURI:rootURI];
        if (schemaJSON) {
            schema = [[RIXJSONSchemaValidatorSchema alloc] initWithSchema:schemaJSON URI:rootURI validator:self];
            _URIToSchema[rootURI] = schema;
            RIXJSONSchemaValidatorSchema *retVal = [schema schemaAtJSONPointer:[URI JSONPointer]];
            return retVal;
        }
    }
    return nil;
}

/**
 * Tests if string matches the given regex in pattern. Uses cached
 * NSRegularExpression instances.
 */
- (BOOL)doesString:(NSString *)string
      matchPattern:(NSString *)pattern
{
    NSRegularExpression *regex = [self regularExpressionForPattern:pattern];
    NSInteger matchCount = [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, string.length)];
    return (matchCount > 0);
}

/**
 * Returns an NSRegularExpression for the given pattern, returning cached
 * instances when possible.
 */
- (NSRegularExpression *)regularExpressionForPattern:(NSString *)pattern
{
    NSRegularExpression *regex = self.patternToRegex[pattern];
    if (regex) {
        return regex;
    }
    NSError *error = nil;
    regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionUseUnicodeWordBoundaries error:&error];
    if (!self.patternToRegex) {
        self.patternToRegex = [[NSMutableDictionary alloc] init];
    }
    self.patternToRegex[pattern] = regex;
    return regex;
}

@end
