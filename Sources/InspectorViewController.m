#import "InspectorViewController.h"
#import "AppRecord.h"
#import "StateScanner.h"
#import "InspectionFinding.h"
#import "SnapshotStore.h"
#import "FindingDetailViewController.h"

@interface InspectorViewController ()
@property (nonatomic, strong) AppRecord *app;
@property (nonatomic, copy) NSArray<InspectionFinding *> *findings;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation InspectorViewController

- (instancetype)initWithApp:(AppRecord *)app {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) _app = app;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.app.name;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.findings = @[];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 5;
    return self.findings.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Target";
    if (section == 1) return @"Read-only inspector";
    return [NSString stringWithFormat:@"Purchase Candidates (%lu)", (unsigned long)self.findings.count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        NSDate *date = [SnapshotStore snapshotDateForBundleID:self.app.bundleID];
        if (date) return [NSString stringWithFormat:@"Saved snapshot: %@\nNo target-app files are modified. Diff mode compares file hashes, plist/JSON/binary-plist values and readable SQLite/CoreData rows.", date];
        return @"No target-app files are modified. For strongest evidence: take Snapshot Before, perform an authorized purchase/restore/test action, then Compare After.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.detailTextLabel.numberOfLines = 3;

    if (indexPath.section == 0) {
        NSArray *labels = @[@"Bundle ID", @"Version", @"Bundle path", @"Data path"];
        NSArray *values = @[self.app.bundleID ?: @"—", self.app.version ?: @"—", self.app.bundleURL.path ?: @"Unavailable", self.app.dataURL.path ?: @"Unavailable"];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 1) {
        NSArray *labels = @[@"Analyze Purchase State", @"StoreKit / Product Clues", @"Snapshot Before", @"Compare After — Purchase Only", @"Show Raw Changes"];
        NSArray *details = @[
            @"Strict scan: only high-confidence purchase/entitlement plist, JSON and SQLite candidates",
            @"Receipt/StoreKit/product-ID clues, ranked and limited instead of hundreds of generic strings",
            @"Capture the full local state for a before/after comparison",
            @"Show the strongest purchase-related changes only (maximum 20)",
            @"Optional unfiltered diff for debugging; may contain many unrelated app changes"
        ];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = details[indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        InspectionFinding *f = self.findings[indexPath.row];
        cell.textLabel.text = f.keyPath.length ? f.keyPath : f.category;
        NSString *shortValue = f.value ?: @"";
        if (shortValue.length > 180) shortValue = [[shortValue substringToIndex:180] stringByAppendingString:@"…"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@\n%@", f.category ?: @"Finding", f.filePath.lastPathComponent ?: @"", shortValue];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self runLocalScan];
        else if (indexPath.row == 1) [self runStoreKitScan];
        else if (indexPath.row == 2) [self saveSnapshot];
        else if (indexPath.row == 3) [self compareSnapshot];
        else [self compareSnapshotRaw];
    } else if (indexPath.section == 2) {
        [self.navigationController pushViewController:[[FindingDetailViewController alloc] initWithFinding:self.findings[indexPath.row]] animated:YES];
    }
}

- (void)runBusy:(void (^)(void))work completion:(void (^)(void))completion {
    [self.spinner startAnimating];
    self.view.userInteractionEnabled = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        work();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.view.userInteractionEnabled = YES;
            if (completion) completion();
        });
    });
}

- (void)setResults:(NSArray<InspectionFinding *> *)results emptyTitle:(NSString *)title emptyMessage:(NSString *)message {
    self.findings = results ?: @[];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationAutomatic];
    if (self.findings.count == 0) [self show:title message:message];
}

- (void)runLocalScan {
    __block NSArray *results = nil;
    [self runBusy:^{ results = [StateScanner scanApp:self.app]; } completion:^{
        [self setResults:results emptyTitle:@"No strong purchase candidates" emptyMessage:@"No high-confidence purchase/entitlement local-state candidates were detected. Generic values are intentionally hidden. The state may be receipt/server-backed or stored in an unsupported format."];
    }];
}

- (void)runStoreKitScan {
    __block NSArray *results = nil;
    [self runBusy:^{ results = [StateScanner scanStoreKitCluesForApp:self.app]; } completion:^{
        [self setResults:results emptyTitle:@"No StoreKit clues" emptyMessage:@"No receipt path, purchase-related printable string, or likely product identifier was found in the files scanned."];
    }];
}

- (void)saveSnapshot {
    __block NSDictionary *snapshot = nil;
    [self runBusy:^{ snapshot = [StateScanner snapshotApp:self.app]; } completion:^{
        NSError *error = nil;
        BOOL ok = [SnapshotStore saveSnapshot:snapshot bundleID:self.app.bundleID error:&error];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
        [self show:ok ? @"Snapshot saved" : @"Snapshot failed"
              message:ok ? [NSString stringWithFormat:@"Captured %lu state entries. Now perform the authorized test action in the target app, return here, and tap Compare After.", (unsigned long)snapshot.count] : (error.localizedDescription ?: @"Unknown error")];
    }];
}

- (void)compareSnapshot {
    NSDictionary *before = [SnapshotStore loadSnapshotForBundleID:self.app.bundleID];
    if (!before) {
        [self show:@"No snapshot" message:@"Run Snapshot Before first, perform the authorized test action in the target app, then return and tap Compare After."];
        return;
    }
    __block NSDictionary *after = nil;
    [self runBusy:^{ after = [StateScanner snapshotApp:self.app]; } completion:^{
        NSArray *diff = [StateScanner diffFrom:before to:after ?: @{}];
        [self setResults:diff emptyTitle:@"No purchase-related changes" emptyMessage:@"Local changes may exist, but none met the purchase-relevance threshold. Generic cache/session/analytics changes are intentionally hidden. Use Show Raw Changes only if you need the complete diff."];
    }];
}

- (void)compareSnapshotRaw {
    NSDictionary *before = [SnapshotStore loadSnapshotForBundleID:self.app.bundleID];
    if (!before) {
        [self show:@"No snapshot" message:@"Run Snapshot Before first, perform the authorized test action in the target app, then return here."];
        return;
    }
    __block NSDictionary *after = nil;
    [self runBusy:^{ after = [StateScanner snapshotApp:self.app]; } completion:^{
        NSArray *diff = [StateScanner rawDiffFrom:before to:after ?: @{}];
        [self setResults:diff emptyTitle:@"No local differences" emptyMessage:@"No supported local state changed since the snapshot."];
    }];
}

- (void)show:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
