#import "CommandRunner.h"
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@implementation CommandRunner

+ (void)runExecutableCandidates:(NSArray<NSString *> *)candidates arguments:(NSArray<NSString *> *)arguments completion:(CommandCompletion)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *exe = nil;
        for (NSString *candidate in candidates) {
            if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) { exe = candidate; break; }
        }
        if (!exe) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(127, @"Required command was not found."); });
            return;
        }

        NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:exe];
        [parts addObjectsFromArray:arguments ?: @[]];
        char **argv = calloc(parts.count + 1, sizeof(char *));
        for (NSUInteger i = 0; i < parts.count; i++) argv[i] = strdup(parts[i].UTF8String);
        argv[parts.count] = NULL;

        pid_t pid = 0;
        int rc = posix_spawn(&pid, exe.fileSystemRepresentation, NULL, NULL, argv, environ);
        int exitCode = rc;
        if (rc == 0) {
            int status = 0;
            if (waitpid(pid, &status, 0) > 0) {
                if (WIFEXITED(status)) exitCode = WEXITSTATUS(status);
                else if (WIFSIGNALED(status)) exitCode = 128 + WTERMSIG(status);
            }
        }
        for (NSUInteger i = 0; i < parts.count; i++) free(argv[i]);
        free(argv);

        NSString *msg = exitCode == 0 ? @"Command completed successfully." : [NSString stringWithFormat:@"Command exited with code %d. It may require elevated jailbreak privileges.", exitCode];
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(exitCode, msg); });
    });
}

@end
