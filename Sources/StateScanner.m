#import "StateScanner.h"
#import "AppRecord.h"
#import "InspectionFinding.h"
#import <sqlite3.h>

@implementation StateScanner

+ (NSArray<NSString *> *)keywords {
    return @[@"premium", @"pro", @"purchase", @"purchased", @"subscription", @"subscribed",
             @"entitlement", @"license", @"licensed", @"paid", @"unlock", @"unlocked", @"vip",
             @"membership", @"trial", @"receipt", @"productid", @"product_id", @"storekit",
             @"ispro", @"is_pro", @"ispremium", @"is_premium", @"haspremium", @"activeplan"];
}

+ (NSInteger)scoreForText:(NSString *)text matched:(NSString **)matched {
    NSString *lower = text.lowercaseString ?: @"";
    NSInteger score = 0;
    NSString *first = nil;
    for (NSString *k in [self keywords]) {
        if ([lower containsString:k]) {
            score += ([k isEqualToString:@"premium"] || [k isEqualToString:@"subscription"] || [k isEqualToString:@"purchased"] || [k isEqualToString:@"entitlement"]) ? 3 : 1;
            if (!first) first = k;
        }
    }
    if (matched) *matched = first;
    return score;
}

+ (NSString *)stringify:(id)value {
    if (!value || value == [NSNull null]) return @"<null>";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    if ([value isKindOfClass:[NSDate class]]) return [value description];
    if ([value isKindOfClass:[NSData class]]) return [NSString stringWithFormat:@"<data %lu bytes>", (unsigned long)[value length]];
    return [value description];
}

+ (void)flattenObject:(id)obj prefix:(NSString *)prefix file:(NSString *)file all:(NSMutableDictionary *)all findings:(NSMutableArray *)findings {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *component = [key description];
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
    NSString *snapshotKey = [NSString stringWithFormat:@"%@|%@", file, prefix ?: @""];
    all[snapshotKey] = valueString ?: @"";

    NSString *matched = nil;
    NSInteger keyScore = [self scoreForText:prefix matched:&matched];
    NSInteger valueScore = [self scoreForText:valueString matched:NULL];
    NSInteger score = keyScore * 2 + valueScore;
    if (score > 0 && findings) {
        InspectionFinding *f = [InspectionFinding new];
        f.category = @"Structured value";
        f.filePath = file;
        f.keyPath = prefix ?: @"";
        f.value = valueString;
        f.score = score;
        f.reason = matched ? [NSString stringWithFormat:@"Matched keyword: %@", matched] : @"Purchase-state-like value";
        [findings addObject:f];
    }
}

+ (NSArray<NSURL *> *)candidateFilesForApp:(AppRecord *)app {
    if (!app.dataURL) return @[];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray<NSURL *> *roots = [NSMutableArray array];
    for (NSString *relative in @[@"Documents", @"Library/Preferences", @"Library/Application Support"]) {
        NSURL *u = [app.dataURL URLByAppendingPathComponent:relative];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:u.path isDirectory:&isDir] && isDir) [roots addObject:u];
    }

    NSMutableArray<NSURL *> *files = [NSMutableArray array];
    NSSet *extensions = [NSSet setWithArray:@[@"plist", @"json", @"db", @"sqlite", @"sqlite3"]];
    for (NSURL *root in roots) {
        NSDirectoryEnumerator *e = [fm enumeratorAtURL:root includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLFileSizeKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];
        for (NSURL *url in e) {
            NSNumber *regular = nil;
            NSNumber *size = nil;
            [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
            [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
            if (![regular boolValue]) continue;
            if (size.unsignedLongLongValue > 20ULL * 1024ULL * 1024ULL) continue;
            if ([extensions containsObject:url.pathExtension.lowercaseString]) [files addObject:url];
            if (files.count >= 1200) return files;
        }
    }
    return files;
}

+ (void)scanStructuredFile:(NSURL *)url all:(NSMutableDictionary *)all findings:(NSMutableArray *)findings {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (!data) return;
    id obj = nil;
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"plist"]) {
        obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
    } else if ([ext isEqualToString:@"json"]) {
        obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    }
    if (obj) [self flattenObject:obj prefix:@"" file:url.path all:all findings:findings];
}

+ (void)scanSQLite:(NSURL *)url all:(NSMutableDictionary *)all findings:(NSMutableArray *)findings {
    sqlite3 *db = NULL;
    if (sqlite3_open_v2(url.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        return;
    }

    sqlite3_stmt *tables = NULL;
    const char *sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' LIMIT 100";
    if (sqlite3_prepare_v2(db, sql, -1, &tables, NULL) == SQLITE_OK) {
        while (sqlite3_step(tables) == SQLITE_ROW) {
            const unsigned char *t = sqlite3_column_text(tables, 0);
            if (!t) continue;
            NSString *table = [NSString stringWithUTF8String:(const char *)t];
            NSString *escapedTable = [table stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
            NSString *pragma = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\")", escapedTable];
            sqlite3_stmt *cols = NULL;
            if (sqlite3_prepare_v2(db, pragma.UTF8String, -1, &cols, NULL) != SQLITE_OK) continue;
            NSMutableArray<NSString *> *suspiciousCols = [NSMutableArray array];
            while (sqlite3_step(cols) == SQLITE_ROW) {
                const unsigned char *c = sqlite3_column_text(cols, 1);
                if (!c) continue;
                NSString *col = [NSString stringWithUTF8String:(const char *)c];
                NSString *combined = [NSString stringWithFormat:@"%@.%@", table, col];
                if ([self scoreForText:combined matched:NULL] > 0) [suspiciousCols addObject:col];
            }
            sqlite3_finalize(cols);

            for (NSString *col in suspiciousCols) {
                NSString *escapedCol = [col stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
                NSString *query = [NSString stringWithFormat:@"SELECT \"%@\" FROM \"%@\" WHERE \"%@\" IS NOT NULL LIMIT 25", escapedCol, escapedTable, escapedCol];
                sqlite3_stmt *rows = NULL;
                if (sqlite3_prepare_v2(db, query.UTF8String, -1, &rows, NULL) != SQLITE_OK) continue;
                NSInteger idx = 0;
                while (sqlite3_step(rows) == SQLITE_ROW) {
                    NSString *value = @"";
                    int type = sqlite3_column_type(rows, 0);
                    if (type == SQLITE_INTEGER) value = [NSString stringWithFormat:@"%lld", sqlite3_column_int64(rows, 0)];
                    else if (type == SQLITE_FLOAT) value = [NSString stringWithFormat:@"%g", sqlite3_column_double(rows, 0)];
                    else if (type == SQLITE_TEXT) {
                        const unsigned char *txt = sqlite3_column_text(rows, 0);
                        if (txt) value = [NSString stringWithUTF8String:(const char *)txt];
                    } else if (type == SQLITE_BLOB) value = [NSString stringWithFormat:@"<blob %d bytes>", sqlite3_column_bytes(rows, 0)];
                    else value = @"<null>";

                    NSString *keyPath = [NSString stringWithFormat:@"%@.%@[%ld]", table, col, (long)idx++];
                    all[[NSString stringWithFormat:@"%@|%@", url.path, keyPath]] = value;

                    InspectionFinding *f = [InspectionFinding new];
                    f.category = @"SQLite";
                    f.filePath = url.path;
                    f.keyPath = keyPath;
                    f.value = value;
                    f.reason = @"Suspicious table/column name";
                    f.score = 5 + [self scoreForText:keyPath matched:NULL];
                    [findings addObject:f];
                }
                sqlite3_finalize(rows);
            }
        }
    }
    if (tables) sqlite3_finalize(tables);
    sqlite3_close(db);
}

+ (NSDictionary<NSString *,NSString *> *)snapshotApp:(AppRecord *)app {
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    for (NSURL *url in [self candidateFilesForApp:app]) {
        NSString *ext = url.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"plist"] || [ext isEqualToString:@"json"]) {
            [self scanStructuredFile:url all:all findings:nil];
        } else {
            NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];
            if (attrs) {
                all[[NSString stringWithFormat:@"%@|<file-metadata>", url.path]] = [NSString stringWithFormat:@"size=%@ modified=%@", attrs[NSFileSize] ?: @0, attrs[NSFileModificationDate] ?: @""];
            }
        }
    }
    return all;
}

+ (NSArray<InspectionFinding *> *)scanApp:(AppRecord *)app {
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    NSMutableArray<InspectionFinding *> *findings = [NSMutableArray array];
    for (NSURL *url in [self candidateFilesForApp:app]) {
        NSString *ext = url.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"plist"] || [ext isEqualToString:@"json"]) {
            [self scanStructuredFile:url all:all findings:findings];
        } else {
            [self scanSQLite:url all:all findings:findings];
        }
    }
    [findings sortUsingComparator:^NSComparisonResult(InspectionFinding *a, InspectionFinding *b) {
        if (a.score == b.score) return [a.filePath compare:b.filePath];
        return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
    }];
    return findings;
}

+ (NSArray<InspectionFinding *> *)diffFrom:(NSDictionary<NSString *,NSString *> *)before to:(NSDictionary<NSString *,NSString *> *)after {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *keys = [NSMutableSet setWithArray:before.allKeys];
    [keys addObjectsFromArray:after.allKeys];
    for (NSString *compound in keys) {
        NSString *old = before[compound];
        NSString *now = after[compound];
        if ((old == nil && now != nil) || (old != nil && now == nil) || ![old isEqualToString:now]) {
            NSRange split = [compound rangeOfString:@"|" options:NSBackwardsSearch];
            NSString *file = split.location != NSNotFound ? [compound substringToIndex:split.location] : compound;
            NSString *key = split.location != NSNotFound ? [compound substringFromIndex:split.location + 1] : @"";
            InspectionFinding *f = [InspectionFinding new];
            f.category = @"Changed after snapshot";
            f.filePath = file;
            f.keyPath = key;
            f.value = [NSString stringWithFormat:@"Before: %@\nAfter: %@", old ?: @"<missing>", now ?: @"<missing>"];
            f.reason = @"Value changed between snapshots";
            f.score = 100 + [self scoreForText:key matched:NULL];
            [out addObject:f];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(InspectionFinding *a, InspectionFinding *b) {
        if (a.score == b.score) return [a.filePath compare:b.filePath];
        return a.score > b.score ? NSOrderedAscending : NSOrderedDescending;
    }];
    return out;
}

@end
