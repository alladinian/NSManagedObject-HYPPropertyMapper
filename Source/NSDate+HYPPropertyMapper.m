#import "NSDate+HYPPropertyMapper.h"

@implementation NSDate (HYPPropertyMapperDateHandling)

+ (NSDate *)hyp_dateFromDateString:(NSString *)dateString {
    NSDate *parsedDate = nil;

    HYPDateType dateType = [dateString hyp_dateType];
    switch (dateType) {
        case HYPDateTypeISO8601: {
            parsedDate = [self hyp_dateFromISO8601String:dateString];
        } break;
        case HYPDateTypeUnixTimestamp: {
            parsedDate = [self hyp_dateFromUnixTimestampString:dateString];
        } break;
        default: break;
    }

    return parsedDate;
}

+ (NSDate *)hyp_dateFromISO8601String:(NSString *)dateString {
    if (!dateString || [dateString isEqual:[NSNull null]]) {
        return nil;
    }

    // Parse string
    else if ([dateString isKindOfClass:[NSString class]]) {
        if ([dateString length] == [HYPPropertyMapperDateNoTimestampFormat length]) {
            NSMutableString *mutableRemoteValue = [dateString mutableCopy];
            [mutableRemoteValue appendString:HYPPropertyMapperTimestamp];
            dateString = [mutableRemoteValue copy];
        }

        const char *str = [dateString cStringUsingEncoding:NSUTF8StringEncoding];
        size_t length = strlen(str);
        if (length == 0) {
            return nil;
        }

        struct tm tm;
        char newStr[25] = "";
        BOOL hasTimezone = NO;

        NSLog(@"dateString: %@", dateString);

        // 2014-03-30T09:13:00Z
        // Remove Z from date, since `strptime` doesn't use Z
        if (length == 20 && str[length - 1] == 'Z') {
            strncpy(newStr, str, length - 1);
            printf("newStr: %s\n\n", newStr);
        }

        // 2014-03-30T09:13:00-07:00
        else if (length == 25 && str[22] == ':') {
            strncpy(newStr, str, 19);
            hasTimezone = YES;
            printf("newStr: %s\n\n", newStr);
        }

        // 2014-03-30T09:13:00.000Z
        else if (length == 24 && str[length - 1] == 'Z') {
            strncpy(newStr, str, 19);
            printf("newStr: %s\n\n", newStr);
        }

        // 2015-06-23T12:40:08.000+02:00
        else if (length == 29 && str[26] == ':') {
            strncpy(newStr, str, 19);
            hasTimezone = YES;
            printf("newStr: %s\n\n", newStr);
        }

        // 2015-08-23T09:29:30.007450+00:00
        else if (length == 32 && str[29] == ':') {
            strncpy(newStr, str, 19);
            hasTimezone = YES;
            printf("newStr: %s\n\n", newStr);
        }

        // 2015-09-10T13:47:21.116+0000
        else if (length == 28 && str[23] == '+') {
            strncpy(newStr, str, 19);
            hasTimezone = NO;
            printf("newStr: %s\n\n", newStr);
        }

        // 2015-09-10T00:00:00.XXXXXXZ
        else if (str[19] == '.' && str[length - 1] == 'Z') {
            strncpy(newStr, str, 19);
            printf("newStr: %s\n\n", newStr);
        }

        // Poorly formatted timezone
        else {
            strncpy(newStr, str, length > 24 ? 24 : length);
            printf("newStr: %s\n\n", newStr);
        }

        // Timezone
        size_t l = strlen(newStr);
        if (hasTimezone) {
            strncpy(newStr + l, str + length - 6, 3);
            strncpy(newStr + l + 3, str + length - 2, 2);
            printf("newStr: %s\n\n", newStr);
        } else {
            strncpy(newStr + l, "+0000", 5);
            printf("newStr: %s\n\n", newStr);
        }

        // Add null terminator
        newStr[sizeof(newStr) - 1] = 0;

        if (strptime(newStr, "%FT%T%z", &tm) == NULL) {
            return nil;
        }

        time_t t;
        t = mktime(&tm);

        return [NSDate dateWithTimeIntervalSince1970:t];
    }

    NSAssert1(NO, @"Failed to parse date: %@", dateString);
    return nil;
}

+ (NSDate *)hyp_dateFromUnixTimestampNumber:(NSNumber *)unixTimestamp {
    return [self hyp_dateFromUnixTimestampString:[unixTimestamp stringValue]];
}

+ (NSDate *)hyp_dateFromUnixTimestampString:(NSString *)unixTimestamp {
    NSString *parsedString = unixTimestamp;

    NSString *validUnixTimestamp = @"1441843200";
    NSInteger validLength = [validUnixTimestamp length];
    if ([unixTimestamp length] > validLength) {
        parsedString = [unixTimestamp substringToIndex:validLength];
    }

    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *unixTimestampNumber = [numberFormatter numberFromString:parsedString];
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:unixTimestampNumber.doubleValue];

    return date;
}

@end

@implementation NSString (HYPPropertyMapperDateHandling)

- (HYPDateType)hyp_dateType {
    if ([self containsString:@"-"]) {
        return HYPDateTypeISO8601;
    } else {
        return HYPDateTypeUnixTimestamp;
    }
}

@end
