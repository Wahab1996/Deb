#import "ProcessesViewController.h"
#import <dlfcn.h>
#import <sys/types.h>
#import <stdint.h>
#import <stdlib.h>

typedef int (*JBProcListAllPidsFn)(void *buffer, int buffersize);
typedef int (*JBProcNameFn)(int pid, void *buffer, uint32_t buffersize);

static const uint32_t JBProcessNameBufferSize = 1024;

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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
        target:self
        action:@selector(loadProcesses)];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"Search process or PID";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;

    [self loadProcesses];
}

- (void)loadProcesses {
    self.navigationItem.rightBarButtonItem.enabled = NO;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
            NSString *loadError = nil;

            /*
             * libproc.h is intentionally not shipped in some iPhoneOS SDKs.
             * The functions themselves exist on iOS, so resolve them at runtime
             * from /usr/lib/libproc.dylib instead of depending on the private header.
             */
            void *handle = dlopen("/usr/lib/libproc.dylib", RTLD_NOW | RTLD_LOCAL);
            if (!handle) {
                const char *err = dlerror();
                loadError = [NSString stringWithFormat:@"Unable to load libproc: %s", err ?: "unknown error"];
            } else {
                JBProcListAllPidsFn procListAllPids =
                    (JBProcListAllPidsFn)dlsym(handle, "proc_listallpids");
                JBProcNameFn procName =
                    (JBProcNameFn)dlsym(handle, "proc_name");

                if (!procListAllPids || !procName) {
                    loadError = @"Required libproc symbols are unavailable.";
                } else {
                    // proc_listallpids returns a PID COUNT, not a byte count.
                    int estimatedCount = procListAllPids(NULL, 0);
                    if (estimatedCount <= 0) {
                        loadError = @"Unable to read the process list.";
                    } else {
                        // Leave headroom for processes created between the two calls.
                        int capacity = estimatedCount + 64;
                        pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));

                        if (!pids) {
                            loadError = @"Unable to allocate memory for the process list.";
                        } else {
                            int actualCount = procListAllPids(
                                pids,
                                capacity * (int)sizeof(pid_t)
                            );

                            if (actualCount < 0) actualCount = 0;
                            if (actualCount > capacity) actualCount = capacity;

                            for (int i = 0; i < actualCount; i++) {
                                pid_t pid = pids[i];
                                if (pid <= 0) continue;

                                char nameBuffer[JBProcessNameBufferSize] = {0};
                                int length = procName(
                                    (int)pid,
                                    nameBuffer,
                                    (uint32_t)sizeof(nameBuffer)
                                );

                                NSString *name = nil;
                                if (length > 0) {
                                    name = [NSString stringWithUTF8String:nameBuffer];
                                }
                                if (name.length == 0) {
                                    name = @"(unknown)";
                                }

                                [rows addObject:@{
                                    @"pid": @(pid),
                                    @"name": name
                                }];
                            }

                            free(pids);
                        }
                    }
                }

                dlclose(handle);
            }

            [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSComparisonResult byName = [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
                if (byName != NSOrderedSame) return byName;
                return [a[@"pid"] compare:b[@"pid"]];
            }];

            if (loadError) {
                [rows removeAllObjects];
                [rows addObject:@{
                    @"pid": @(-1),
                    @"name": loadError
                }];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                self.allProcesses = [rows copy];
                [self applyFilter:self.searchController.searchBar.text];
                self.navigationItem.rightBarButtonItem.enabled = YES;
            });
        }
    });
}

- (void)applyFilter:(NSString *)query {
    NSString *q = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (q.length == 0) {
        self.visibleProcesses = self.allProcesses ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
            (void)bindings;
            NSString *pid = [row[@"pid"] stringValue];
            return [row[@"name"] localizedCaseInsensitiveContainsString:q] || [pid containsString:q];
        }];
        self.visibleProcesses = [self.allProcesses filteredArrayUsingPredicate:predicate];
    }

    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applyFilter:searchController.searchBar.text];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.visibleProcesses.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"proc"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"proc"];
    }

    NSDictionary *row = self.visibleProcesses[indexPath.row];
    NSNumber *pid = row[@"pid"];

    cell.textLabel.text = row[@"name"];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = pid.intValue >= 0
        ? [NSString stringWithFormat:@"PID %@", pid]
        : @"libproc";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}

@end
