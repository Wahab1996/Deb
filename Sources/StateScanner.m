#import "StateScanner.h"
#import "AppRecord.h"
#import "InspectionFinding.h"
#import <sqlite3.h>
#import <string.h>

@implementation StateScanner

#pragma mark - Heuristics

+ (NSArray<NSString *> *)keywords {
    return @[@"premium", @"pro", @"purchase", @"purchased", @"subscription", @"subscribed",
             @"entitlement", @"license", @"licensed", @"paid", @"unlock", @"unlocked", @"vip",
             @"membership", @"trial", @"receipt", @"productid", @"product_id", @"storekit",
             @"ispro", @"is_pro", @"ispremium", @"is_premium", @"haspremium", @"activeplan",
             @"removeads", @"remove_ads", @"noads", @"no_ads", @"iap", @"inapp", @"in_app",
             @"billing", @"owned", @"ownership", @"accesslevel", @"access_level", @"paywall"];
}

+ (NSInteger)scoreForText:(NSString *)text matched:(NSString **)matched {
    NSString *lower = text.lowercaseString ?: @"";
    NSInteger score = 0;
    NSString *first = nil;
    for (NSString *k in [self keywords]) {
        if ([lower containsString:k]) {
            if (!first) first = k;
            if ([k isEqualToString:@"premium"] || [k isEqualToString:@"purchase"] ||
                [k isEqualToString:@"purchased"] || [k isEqualToString:@"subscription"] ||
                [k isEqualToString:@"entitlement"] || [k isEqualToString:@"receipt"] ||
                [k isEqualToString:@"productid"] || [k isEqualToString:@"product_id"] ||
                [k isEqualToString:@"storekit"]) score += 4;
            else score += 2;
        }
    }
    if (matched) *matched = first;
    return score;
}

+ (BOOL)isDisabledLikeValue:(NSString *)value {
    NSString *v = value.lowercaseString ?: @"";
    return [v isEqualToString:@"0"] || [v isEqualToString:@"false"] ||
           [v isEqualToString:@"no"] || [v isEqualToString:@"inactive"] ||
           [v isEqualToString:@"locked"] || [v isEqualToString:@"disabled"] ||
           [v isEqualToString:@"none"] || [v isEqualToString:@"free"];
}

+ (NSString *)stringify:(id)value {
    if (!value || value == [NSNull null]) return @"<null>";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    if ([value isKindOfClass:[NSDate class]]) return [value description];
    if ([value isKindOfClass:[NSData class]]) return [NSString stringWithFormat:@"<data %lu bytes>", (unsigned long)[value length]];
    return [value description] ?: @"";
}

+ (InspectionFinding *)finding:(NSString *)category
                          file:(NSString *)file
                           key:(NSString *)key
                         value:(NSString *)value
                        reason:(NSString *)reason
                         score:(NSInteger)score {
    InspectionFinding *f = [InspectionFinding new];
    f.category = category ?: @"Finding";
    f.filePath = file ?: @"";
    f.keyPath = key ?: @"";
    f.value = value ?: @"";
    f.reason = reason ?: @"";
    f.score = score;
    return f;
}

#pragma mark - File discovery / hashing

+ (NSArray<NSURL *> *)allDataFilesForApp:(AppRecord *)app {
    if (!app.dataURL) return @[];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray<NSURL *> *files = [NSMutableArray array];
    NSArray *keys = @[NSURLIsRegularFileKey, NSURLFileSizeKey, NSURLNameKey];
    NSDirectoryEnumerator *e = [fm enumeratorAtURL:app.dataURL
                       includingPropertiesForKeys:keys
                                          options:0
                                     errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];
    for (NSURL *url in e) {
        NSNumber *regular = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (![regular boolValue]) continue;
        [files addObject:url];
        if (files.count >= 6000) break;
    }
    return files;
}

+ (uint64_t)fnv1aForURL:(NSURL *)url maxBytes:(uint64_t)maxBytes sampled:(BOOL *)sampled {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
    if (!fh) return 0;
    uint64_t hash = 1469598103934665603ULL;
    uint64_t total = 0;
    BOOL cut = NO;
    @try {
        while (total < maxBytes) {
            @autoreleasepool {
                NSUInteger want = (NSUInteger)MIN((uint64_t)(128 * 1024), maxBytes - total);
                NSData *chunk = [fh readDataOfLength:want];
                if (chunk.length == 0) break;
                const uint8_t *bytes = chunk.bytes;
                for (NSUInteger i = 0; i < chunk.length; i++) {
                    hash ^= bytes[i];
                    hash *= 1099511628211ULL;
                }
                total += chunk.length;
            }
        }
        NSData *probe = [fh readDataOfLength:1];
        cut = probe.length > 0;
    } @catch (__unused NSException *ex) {
    }
    [fh closeFile];
    if (sampled) *sampled = cut;
    return hash;
}

+ (NSString *)fileSignature:(NSURL *)url {
    NSDictionary *a = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];
    if (!a) return @"unreadable";
    unsigned long long size = [a[NSFileSize] unsignedLongLongValue];
    NSDate *modified = a[NSFileModificationDate];
    BOOL sampled = NO;
    uint64_t h = [self fnv1aForURL:url maxBytes:(64ULL * 1024ULL * 1024ULL) sampled:&sampled];
    return [NSString stringWithFormat:@"size=%llu|mtime=%.3f|fnv64=%016llx%@",
            size, modified ? modified.timeIntervalSince1970 : 0,
            (unsigned long long)h, sampled ? @"|sampled=1" : @""];
}

+ (BOOL)looksLikeSQLite:(NSURL *)url {
    NSData *d = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (d.length < 16) return NO;
    const char sig[] = "SQLite format 3\0";
    return memcmp(d.bytes, sig, 16) == 0;
}

+ (id)structuredObjectForURL:(NSURL *)url {
    NSDictionary *a = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];
    if ([a[NSFileSize] unsignedLongLongValue] > 24ULL * 1024ULL * 1024ULL) return nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (!data.length) return nil;

    NSString *ext = url.pathExtension.lowercaseString ?: @"";
    BOOL maybePlist = [ext isEqualToString:@"plist"] ||
                      (data.length >= 8 && memcmp(data.bytes, "bplist00", 8) == 0) ||
                      (data.length >= 5 && memcmp(data.bytes, "<?xml", 5) == 0);
    if (maybePlist) {
        id p = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
        if (p) return p;
    }

    BOOL maybeJSON = [ext isEqualToString:@"json"];
    if (!maybeJSON) {
        const uint8_t *b = data.bytes;
        NSUInteger i = 0;
        while (i < data.length && (b[i] == ' ' || b[i] == '\n' || b[i] == '\r' || b[i] == '\t')) i++;
        if (i < data.length && (b[i] == '{' || b[i] == '[')) maybeJSON = YES;
    }
    if (maybeJSON) {
        id j = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        if (j) return j;
    }
    return nil;
}

#pragma mark - Structured values

+ (void)flattenObject:(id)obj
               prefix:(NSString *)prefix
                 file:(NSString *)file
                  all:(NSMutableDictionary<NSString *, NSString *> *)all
             findings:(NSMutableArray<InspectionFinding *> *)findings {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *component = [key description] ?: @"?";
            NSString *next = prefix.length ? [prefix stringByAppendingFormat:@".%@", component] : component;
            [self flattenObject:value prefix:next file:file all:all findings:findings];
        }];
        return;
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        [(NSArray *)obj enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
            NSString *next = [prefix stringByAppendingFormat:@"[%lu]", (unsigned long)idx];
            [self flattenObject:value prefix:next file:file all:all findings:findings];
        }];
        return;
    }

    NSString *valueString = [self stringify:obj];
    NSString *snapshotKey = [NSString stringWithFormat:@"VALUE|%@|%@", file ?: @"", prefix ?: @""];
    if (all) all[snapshotKey] = valueString ?: @"";

    if (!findings) return;
    NSString *matched = nil;
    NSInteger keyScore = [self scoreForText:prefix matched:&matched];
    NSInteger valueScore = [self scoreForText:valueString matched:NULL];
    NSInteger score = keyScore * 2 + valueScore;
    if (score > 0) {
        BOOL disabled = [self isDisabledLikeValue:valueString];
        NSString *reason = matched ? [NSString stringWithFormat:@"Purchase-state-like key matched '%@'%@", matched, disabled ? @" and its current value looks disabled/locked" : @""] : @"Purchase-state-like value";
        [findings addObject:[self finding:@"Structured state" file:file key:prefix value:valueString reason:reason score:score + (disabled ? 4 : 0)]];
    }
}

#pragma mark - SQLite / CoreData

+ (NSString *)sqliteStringAtColumn:(sqlite3_stmt *)stmt index:(int)i {
    int type = sqlite3_column_type(stmt, i);
    if (type == SQLITE_NULL) return @"<null>";
    if (type == SQLITE_INTEGER) return [NSString stringWithFormat:@"%lld", sqlite3_column_int64(stmt, i)];
    if (type == SQLITE_FLOAT) return [NSString stringWithFormat:@"%.17g", sqlite3_column_double(stmt, i)];
    if (type == SQLITE_TEXT) {
        const unsigned char *txt = sqlite3_column_text(stmt, i);
        if (!txt) return @"";
        NSString *decoded = [NSString stringWithUTF8String:(const char *)txt];
        return decoded ?: @"<non-UTF8 text>";
    }
    if (type == SQLITE_BLOB) return [NSString stringWithFormat:@"<blob %d bytes>", sqlite3_column_bytes(stmt, i)];
    return @"<?>";
}

+ (void)scanSQLite:(NSURL *)url
               all:(NSMutableDictionary<NSString *, NSString *> *)all
          findings:(NSMutableArray<InspectionFinding *> *)findings
          fullRows:(BOOL)fullRows {
    sqlite3 *db = NULL;
    if (sqlite3_open_v2(url.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        return;
    }
    sqlite3_busy_timeout(db, 150);

    sqlite3_stmt *tables = NULL;
    const char *sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' LIMIT 150";
    if (sqlite3_prepare_v2(db, sql, -1, &tables, NULL) == SQLITE_OK) {
        while (sqlite3_step(tables) == SQLITE_ROW) {
            const unsigned char *t = sqlite3_column_text(tables, 0);
            if (!t) continue;
            NSString *table = [NSString stringWithUTF8String:(const char *)t];
            NSString *escapedTable = [table stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
            NSString *query = [NSString stringWithFormat:@"SELECT * FROM \"%@\" LIMIT %d", escapedTable, fullRows ? 250 : 60];
            sqlite3_stmt *rows = NULL;
            if (sqlite3_prepare_v2(db, query.UTF8String, -1, &rows, NULL) != SQLITE_OK) continue;

            int columnCount = sqlite3_column_count(rows);
            NSMutableArray<NSString *> *columnNames = [NSMutableArray arrayWithCapacity:MAX(columnCount, 0)];
            for (int i = 0; i < columnCount; i++) {
                const char *n = sqlite3_column_name(rows, i);
                [columnNames addObject:n ? [NSString stringWithUTF8String:n] : [NSString stringWithFormat:@"col%d", i]];
            }

            NSInteger rowIndex = 0;
            while (sqlite3_step(rows) == SQLITE_ROW) {
                for (int i = 0; i < columnCount; i++) {
                    NSString *col = columnNames[(NSUInteger)i];
                    NSString *value = [self sqliteStringAtColumn:rows index:i];
                    NSString *keyPath = [NSString stringWithFormat:@"%@.row[%ld].%@", table, (long)rowIndex, col];
                    if (all) all[[NSString stringWithFormat:@"SQLITE|%@|%@", url.path, keyPath]] = value ?: @"";

                    if (findings) {
                        NSString *matched = nil;
                        NSInteger nameScore = [self scoreForText:[NSString stringWithFormat:@"%@.%@", table, col] matched:&matched];
                        NSInteger valueScore = [self scoreForText:value matched:NULL];
                        NSInteger score = nameScore * 2 + valueScore;
                        if (score > 0) {
                            BOOL disabled = [self isDisabledLikeValue:value];
                            NSString *reason = matched ? [NSString stringWithFormat:@"SQLite table/column matched '%@'%@", matched, disabled ? @"; current value looks disabled/locked" : @""] : @"Purchase-state-like SQLite value";
                            [findings addObject:[self finding:@"SQLite/CoreData" file:url.path key:keyPath value:value reason:reason score:score + (disabled ? 4 : 0)]];
                        }
                    }
                }
                rowIndex++;
            }
            sqlite3_finalize(rows);
        }
    }
    if (tables) sqlite3_finalize(tables);
    sqlite3_close(db);
}

#pragma mark - String / StoreKit clues

+ (NSArray<NSString *> *)printableStringsFromData:(NSData *)data maxStrings:(NSUInteger)maxStrings {
    if (!data.length) return @[];
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSMutableData *run = [NSMutableData data];
    const uint8_t *b = data.bytes;
    for (NSUInteger i = 0; i < data.length && out.count < maxStrings; i++) {
        uint8_t c = b[i];
        BOOL printable = (c >= 0x20 && c <= 0x7e);
        if (printable) {
            [run appendBytes:&c length:1];
            if (run.length > 220) [run setLength:0];
        } else {
            if (run.length >= 4) {
                NSString *s = [[NSString alloc] initWithData:run encoding:NSUTF8StringEncoding];
                if (s.length) [out addObject:s];
            }
            [run setLength:0];
        }
    }
    if (run.length >= 4 && out.count < maxStrings) {
        NSString *s = [[NSString alloc] initWithData:run encoding:NSUTF8StringEncoding];
        if (s.length) [out addObject:s];
    }
    return out;
}

+ (BOOL)looksLikeProductIdentifier:(NSString *)s {
    if (s.length < 6 || s.length > 180 || [s containsString:@" "]) return NO;
    NSArray *parts = [s componentsSeparatedByString:@"."];
    if (parts.count < 2) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
    return [s rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

+ (NSArray<NSURL *> *)bundleFilesForClues:(AppRecord *)app {
    if (!app.bundleURL) return @[];
    NSMutableArray *files = [NSMutableArray array];
    NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtURL:app.bundleURL
                                                 includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLFileSizeKey]
                                                                    options:0
                                                               errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];
    for (NSURL *url in e) {
        NSNumber *regular = nil, *size = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        if (![regular boolValue] || size.unsignedLongLongValue > 18ULL * 1024ULL * 1024ULL) continue;
        [files addObject:url];
        if (files.count >= 800) break;
    }
    return files;
}

+ (NSArray<InspectionFinding *> *)scanStoreKitCluesForApp:(AppRecord *)app {
    NSMutableArray<InspectionFinding *> *findings = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSMutableArray<NSURL *> *files = [NSMutableArray arrayWithArray:[self bundleFilesForClues:app]];
    for (NSURL *u in [self allDataFilesForApp:app]) {
        NSDictionary *a = [NSFileManager.defaultManager attributesOfItemAtPath:u.path error:nil];
        if ([a[NSFileSize] unsignedLongLongValue] <= 8ULL * 1024ULL * 1024ULL) [files addObject:u];
        if (files.count >= 1200) break;
    }

    for (NSURL *url in files) {
        NSString *lowerPath = url.path.lowercaseString;
        if (([url.lastPathComponent.lowercaseString isEqualToString:@"receipt"] || [lowerPath containsString:@"/storekit/"] || [lowerPath containsString:@"_masreceipt"]) && ![seen containsObject:url.path]) {
            [seen addObject:url.path];
            [findings addObject:[self finding:@"Receipt / StoreKit file" file:url.path key:@"<file>" value:[self fileSignature:url] reason:@"Receipt/StoreKit-related path detected. Inspector reports metadata only; it does not alter or forge receipts." score:12]];
        }

        NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
        if (!data.length) continue;
        for (NSString *s in [self printableStringsFromData:data maxStrings:2500]) {
            NSString *matched = nil;
            NSInteger score = [self scoreForText:s matched:&matched];
            BOOL productish = [self looksLikeProductIdentifier:s] &&
                              ([s.lowercaseString containsString:@"premium"] ||
                               [s.lowercaseString containsString:@"subscription"] ||
                               [s.lowercaseString containsString:@"iap"] ||
                               [s.lowercaseString containsString:@"pro"] ||
                               [s.lowercaseString containsString:@"coin"] ||
                               [s.lowercaseString containsString:@"remove"] ||
                               [s.lowercaseString containsString:@"ad"]);
            if (score == 0 && !productish) continue;
            NSString *dedupe = [NSString stringWithFormat:@"%@|%@", url.path, s];
            if ([seen containsObject:dedupe]) continue;
            [seen addObject:dedupe];
            NSString *reason = productish ? @"Possible StoreKit product identifier / purchase-related constant" : [NSString stringWithFormat:@"Purchase/StoreKit-related string matched '%@'", matched ?: @"keyword"];
            [findings addObject:[self finding:productish ? @"Possible Product ID" : @"StoreKit string" file:url.path key:@"<printable string>" value:s reason:reason score:(productish ? 10 : 5 + score)]];
            if (findings.count >= 500) break;
        }
        if (findings.count >= 500) break;
    }

    [findings sortUsingComparator:^NSComparisonResult(InspectionFinding *a, InspectionFinding *b) {
        if (a.score != b.score) return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
        return [a.filePath compare:b.filePath];
    }];
    return findings;
}

#pragma mark - Public scan

+ (NSArray<InspectionFinding *> *)scanApp:(AppRecord *)app {
    NSMutableArray<InspectionFinding *> *findings = [NSMutableArray array];
    for (NSURL *url in [self allDataFilesForApp:app]) {
        @autoreleasepool {
            id obj = [self structuredObjectForURL:url];
            if (obj) [self flattenObject:obj prefix:@"" file:url.path all:nil findings:findings];
            if ([self looksLikeSQLite:url]) [self scanSQLite:url all:nil findings:findings fullRows:NO];

            NSString *lowerPath = url.path.lowercaseString;
            NSString *matched = nil;
            NSInteger pathScore = [self scoreForText:lowerPath matched:&matched];
            if (pathScore > 0) {
                [findings addObject:[self finding:@"Purchase-related file" file:url.path key:@"<file>" value:[self fileSignature:url] reason:[NSString stringWithFormat:@"File path/name matched '%@'", matched ?: @"purchase keyword"] score:pathScore + 2]];
            }
            if (findings.count >= 1200) break;
        }
    }
    [findings sortUsingComparator:^NSComparisonResult(InspectionFinding *a, InspectionFinding *b) {
        if (a.score != b.score) return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
        return [a.filePath compare:b.filePath];
    }];
    return findings;
}

#pragma mark - Full snapshot

+ (NSDictionary<NSString *, NSString *> *)snapshotApp:(AppRecord *)app {
    NSMutableDictionary<NSString *, NSString *> *all = [NSMutableDictionary dictionary];
    for (NSURL *url in [self allDataFilesForApp:app]) {
        @autoreleasepool {
            all[[NSString stringWithFormat:@"FILE|%@", url.path]] = [self fileSignature:url];

            id obj = [self structuredObjectForURL:url];
            if (obj) [self flattenObject:obj prefix:@"" file:url.path all:all findings:nil];
            if ([self looksLikeSQLite:url]) [self scanSQLite:url all:all findings:nil fullRows:YES];

            if (all.count >= 120000) {
                all[@"META|TRUNCATED"] = @"Snapshot reached safety limit of 120000 entries";
                break;
            }
        }
    }
    all[@"META|BUNDLE_ID"] = app.bundleID ?: @"";
    all[@"META|CAPTURED_AT"] = [NSString stringWithFormat:@"%.3f", NSDate.date.timeIntervalSince1970];
    return all;
}

+ (NSArray<InspectionFinding *> *)diffFrom:(NSDictionary<NSString *, NSString *> *)before
                                        to:(NSDictionary<NSString *, NSString *> *)after {
    NSMutableArray<InspectionFinding *> *changes = [NSMutableArray array];
    NSMutableSet<NSString *> *keys = [NSMutableSet setWithArray:before.allKeys];
    [keys addObjectsFromArray:after.allKeys];
    [keys removeObject:@"META|CAPTURED_AT"];

    for (NSString *snapshotKey in keys) {
        NSString *old = before[snapshotKey];
        NSString *now = after[snapshotKey];
        if ((old == nil && now == nil) || [old isEqualToString:now]) continue;

        NSArray<NSString *> *parts = [snapshotKey componentsSeparatedByString:@"|"];
        NSString *kind = parts.count ? parts[0] : @"VALUE";
        NSString *file = parts.count > 1 ? parts[1] : @"";
        NSString *keyPath = parts.count > 2 ? [[parts subarrayWithRange:NSMakeRange(2, parts.count - 2)] componentsJoinedByString:@"|"] : @"<file>";

        NSString *category = @"State changed";
        NSInteger score = 15;
        if ([kind isEqualToString:@"FILE"]) { category = @"File changed"; score = 8; }
        else if ([kind isEqualToString:@"SQLITE"]) { category = @"SQLite/CoreData changed"; score = 18; }
        else if ([kind isEqualToString:@"VALUE"]) { category = @"Structured value changed"; score = 20; }
        else if ([kind isEqualToString:@"META"]) continue;

        NSInteger clue = [self scoreForText:[NSString stringWithFormat:@"%@ %@ %@", file, keyPath, now ?: old ?: @""] matched:NULL];
        score += clue * 2;
        NSString *value = nil;
        NSString *reason = nil;
        if (!old) {
            value = [NSString stringWithFormat:@"ADDED\n%@", now ?: @"<null>"];
            reason = @"This file/value appeared after the snapshot.";
        } else if (!now) {
            value = [NSString stringWithFormat:@"REMOVED\n%@", old];
            reason = @"This file/value disappeared after the snapshot.";
        } else {
            value = [NSString stringWithFormat:@"BEFORE\n%@\n\nAFTER\n%@", old, now];
            reason = @"Exact local state difference detected between Snapshot Before and Compare After.";
        }
        [changes addObject:[self finding:category file:file key:keyPath value:value reason:reason score:score]];
        if (changes.count >= 3000) break;
    }

    [changes sortUsingComparator:^NSComparisonResult(InspectionFinding *a, InspectionFinding *b) {
        if (a.score != b.score) return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
        return [a.filePath compare:b.filePath];
    }];
    return changes;
}

@end
