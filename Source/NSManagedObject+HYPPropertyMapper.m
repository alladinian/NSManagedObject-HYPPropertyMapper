#import "NSManagedObject+HYPPropertyMapper.h"

#import "NSString+HYPNetworking.h"
#import "NSDate+HYPPropertyMapper.h"
#import "NSManagedObject+HYPPropertyMapperHelpers.h"

static NSString * const HYPPropertyMapperNestedAttributesKey = @"attributes";
static NSString * const HYPPropertyMapperDestroyKey = @"destroy";

@implementation NSManagedObject (HYPPropertyMapper)

#pragma mark - Public methods

- (void)hyp_fillWithDictionary:(NSDictionary *)dictionary {
    for (__strong NSString *key in dictionary) {

        id value = [dictionary objectForKey:key];

        BOOL isReservedKey = ([[NSManagedObject reservedAttributes] containsObject:key]);
        if (isReservedKey) {
            key = [self prefixedAttribute:key];
        }

        NSAttributeDescription *attributeDescription = [self attributeDescriptionForRemoteKey:key];
        if (attributeDescription) {
            NSString *localKey = attributeDescription.name;

            BOOL valueExists = (value &&
                                ![value isKindOfClass:[NSNull class]]);
            if (valueExists) {
                id processedValue = [self valueForAttributeDescription:attributeDescription
                                                      usingRemoteValue:value];

                BOOL valueHasChanged = (![[self valueForKey:localKey] isEqual:processedValue]);
                if (valueHasChanged) {
                    [self setValue:processedValue forKey:localKey];
                }
            } else if ([self valueForKey:localKey]) {
                [self setValue:nil forKey:localKey];
            }
        }
    }
}

- (NSDictionary *)hyp_dictionary {
    return [self hyp_dictionaryWithDateFormatter:[self defaultDateFormatter] usingRelationshipType:HYPPropertyMapperRelationshipTypeNested];
}

- (NSDictionary *)hyp_dictionaryUsingRelationshipType:(HYPPropertyMapperRelationshipType)relationshipType {
    return [self hyp_dictionaryWithDateFormatter:[self defaultDateFormatter] usingRelationshipType:relationshipType];
}

- (NSDictionary *)hyp_dictionaryWithDateFormatter:(NSDateFormatter *)formatter {
    return [self hyp_dictionaryWithDateFormatter:formatter usingRelationshipType:HYPPropertyMapperRelationshipTypeNested];
}

- (NSDictionary *)hyp_dictionaryWithDateFormatter:(NSDateFormatter *)formatter usingRelationshipType:(HYPPropertyMapperRelationshipType)relationshipType {
    NSMutableDictionary *managedObjectAttributes = [NSMutableDictionary new];

    for (id propertyDescription in self.entity.properties) {
        if ([propertyDescription isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *attributeDescription = (NSAttributeDescription *)propertyDescription;
            if (attributeDescription.attributeType != NSTransformableAttributeType) {
                id value = [self valueForKey:attributeDescription.name];
                BOOL nilOrNullValue = (!value ||
                                       [value isKindOfClass:[NSNull class]]);
                if (nilOrNullValue) {
                    value = [NSNull null];
                } else if ([value isKindOfClass:[NSDate class]]) {
                    value = [formatter stringFromDate:value];
                }

                NSString *remoteKey = [self remoteKeyForAttributeDescription:attributeDescription];
                managedObjectAttributes[remoteKey] = value;
            }
        } else if ([propertyDescription isKindOfClass:[NSRelationshipDescription class]] &&
                   relationshipType != HYPPropertyMapperRelationshipTypeNone) {
            NSString *relationshipName = [propertyDescription name];

            id relationships = [self valueForKey:relationshipName];
            BOOL isToOneRelationship = (![relationships isKindOfClass:[NSSet class]]);
            if (isToOneRelationship) {
                continue;
            }

            NSUInteger relationIndex = 0;
            NSMutableDictionary *relationsDictionary = [NSMutableDictionary new];
            NSMutableArray *relationsArray = [NSMutableArray new];
            for (NSManagedObject *relation in relationships) {
                BOOL hasValues = NO;
                NSMutableDictionary *dictionary = [NSMutableDictionary new];
                for (NSAttributeDescription *propertyDescription in [relation.entity properties]) {
                    if ([propertyDescription isKindOfClass:[NSAttributeDescription class]]) {
                        NSAttributeDescription *attributeDescription = (NSAttributeDescription *)propertyDescription;
                        id value = [relation valueForKey:[attributeDescription name]];
                        if (value) {
                            hasValues = YES;
                        } else {
                            continue;
                        }

                        NSString *attribute = [propertyDescription name];
                        NSString *localKey = HYPPropertyMapperDefaultLocalValue;
                        BOOL attributeIsKey = ([localKey isEqualToString:attribute]);

                        NSString *key;
                        if (attributeIsKey) {
                            key = HYPPropertyMapperDefaultRemoteValue;
                        } else if ([attribute isEqualToString:HYPPropertyMapperDestroyKey] &&
                                   relationshipType == HYPPropertyMapperRelationshipTypeNested) {
                            key = [NSString stringWithFormat:@"_%@", HYPPropertyMapperDestroyKey];
                        } else {
                            key = [attribute hyp_remoteString];
                        }

                        if (value) {
                            if (relationshipType == HYPPropertyMapperRelationshipTypeArray) {
                                dictionary[key] = value;
                            } else if (relationshipType == HYPPropertyMapperRelationshipTypeNested) {
                                NSString *relationIndexString = [NSString stringWithFormat:@"%lu", (unsigned long)relationIndex];
                                NSMutableDictionary *dictionary = [relationsDictionary[relationIndexString] mutableCopy] ?: [NSMutableDictionary new];
                                dictionary[key] = value;
                                relationsDictionary[relationIndexString] = dictionary;
                            }
                        }
                    }
                }

                if (relationshipType == HYPPropertyMapperRelationshipTypeArray) {
                    if (dictionary.count > 0) {
                        [relationsArray addObject:dictionary];
                    }
                } else if (relationshipType == HYPPropertyMapperRelationshipTypeNested) {
                    if (hasValues) {
                        relationIndex++;
                    }
                }
            }

            if (relationshipType == HYPPropertyMapperRelationshipTypeArray) {
                [managedObjectAttributes setValue:relationsArray forKey:[relationshipName hyp_remoteString]];
            } else if (relationshipType == HYPPropertyMapperRelationshipTypeNested) {
                NSString *nestedAttributesPrefix = [NSString stringWithFormat:@"%@_%@", [relationshipName hyp_remoteString], HYPPropertyMapperNestedAttributesKey];
                [managedObjectAttributes setValue:relationsDictionary forKey:nestedAttributesPrefix];
            }
        }
    }

    return [managedObjectAttributes copy];
}


#pragma mark - Private

- (NSDateFormatter *)defaultDateFormatter {
    static NSDateFormatter *_dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateFormatter = [NSDateFormatter new];
        _dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    });

    return _dateFormatter;
}

@end
