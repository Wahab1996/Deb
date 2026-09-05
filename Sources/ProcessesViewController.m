#import "ProcessesViewController.h"
#import <libproc.h>

@interface ProcessesViewController () <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSDictionary *> *allProcesses;
@property (nonatomic, strong) NSArray<NSDictionary *> *visibleProcesses;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation ProcessesViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Processes";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadProcesses)];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"Search process or PID";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    [self loadProcesses];
}

- (void)loadProcesses {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int count = proc_listallpids(NULL, 0);
        if (count <= 0) count = 2048;
        pid_t *pids = calloc((size_t)count, sizeof(pid_t));
        int bytes = proc_listallpids(pids, count * (int)sizeof(pid_t));
        int actual = bytes / (int)sizeof(pid_t);
        NSMutableArray *rows = [NSMutableArray array];
        for (int i = 0; i < actual; i++) {
            if (pids[i] <= 0) continue;
            char namebuf[PROC_PIDPATHINFO_MAXSIZE] = {0};
            int n = proc_name(pids[i], namebuf, sizeof(namebuf));
            NSString *name = n > 0 ? [NSString stringWithUTF8String:namebuf] : @"(unknown)";
            [rows addObject:@{@"pid": @(pids[i]), @"name": name ?: @"(unknown)"}];
        }
        free(pids);
        [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allProcesses = rows;
            [self applyFilter:self.searchController.searchBar.text];
        });
    });
}

- (void)applyFilter:(NSString *)query {
    NSString *q = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (q.length == 0) {
        self.visibleProcesses = self.allProcesses ?: @[];
    } else {
        NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
            (void)bindings;
            NSString *pid = [row[@"pid"] stringValue];
            return [row[@"name"] localizedCaseInsensitiveContainsString:q] || [pid containsString:q];
        }];
        self.visibleProcesses = [self.allProcesses filteredArrayUsingPredicate:p];
    }
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applyFilter:searchController.searchBar.text];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return self.visibleProcesses.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"proc"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"proc"];
    NSDictionary *row = self.visibleProcesses[indexPath.row];
    cell.textLabel.text = row[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"PID %@", row[@"pid"]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
