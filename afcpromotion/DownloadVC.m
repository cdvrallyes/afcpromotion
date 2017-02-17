//
//  DownloadVC.m
//  afcpromotion
//
//  Created by Olivier on 16/02/2017.
//  Copyright © 2017 Olivier. All rights reserved.
//

#import "DownloadVC.h"

#define USERPREF_INSTALL        @"USERPREF_INSTALL"

@interface DownloadVC ()
@property (weak, nonatomic) IBOutlet UIProgressView *pvProgress;
@property (weak, nonatomic) IBOutlet UIButton *btForceDL;
@property (weak, nonatomic) IBOutlet UIButton *btGetEmails;

@end

@implementation DownloadVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    [[self pvProgress] setProgress:0];
    [[self pvProgress] setHidden:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (void)viewDidAppear:(BOOL)animated {
#ifdef BUNDLED_DATA
    [self nextScreen:YES];
#elif DEBUG
    NSNumber * n = [[NSUserDefaults standardUserDefaults] objectForKey:USERPREF_INSTALL];
    if([n boolValue]) {
        [self nextScreen:YES];
    }
#else
    [self downloadPackage];
#endif
}

- (IBAction)onForceClicked:(id)sender {
    [self downloadPackage];
}

- (IBAction)onEmailsClicked:(id)sender {
    
    mBlock = YES;
    NSData * data = [NSData dataWithContentsOfFile:[DataManager emailDatabasePath]];
    
    
//    Your application has presented a UIActivityViewController (<UIActivityViewController: 0x7fc510721c00>). In its current trait environment, the modalPresentationStyle of a UIActivityViewController with this style is UIModalPresentationPopover. You must provide location information for this popover through the view controller's popoverPresentationController. You must provide either a sourceView and sourceRect or a barButtonItem.  If this information is not known when you present the view controller, you may provide it in the UIPopoverPresentationControllerDelegate method -prepareForPopoverPresentation.'
//        *** First throw call stack:
    
    NSString * df = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
    NSString * path = [NSString stringWithFormat:@"%@/%@-%@", [DataManager dataPath], df, EMAIL_DATABASE];
    UIActivityViewController * vc = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObjects:path, data, nil] applicationActivities:nil];
    
    UIPopoverPresentationController * pop = [vc popoverPresentationController];
    pop.sourceView = [self btGetEmails];
    pop.sourceRect = self.btGetEmails.bounds;

    [vc setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSLog(@"completed: %@, \n%d, \n%@, \n%@,", activityType, completed, returnedItems, activityError);
        mBlock = NO;
        [self nextScreen:NO];
    }];
    
    [self presentViewController:vc animated:YES completion:^{
        ;
    }];
    
}

- (void) nextScreen:(BOOL)aWait {
#ifdef DEBUG
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:USERPREF_INSTALL];
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
    [NSTimer scheduledTimerWithTimeInterval:aWait ? 5.0 : 0.1 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if(mBlock == NO) {
            UINavigationController * nc = [[self storyboard] instantiateViewControllerWithIdentifier:@"idMapVC"];
            [[self navigationController] pushViewController:nc animated:NO];
        }
    }];
}


- (void)downloadPackage {
    mBlock = YES;
    [[self pvProgress] setHidden:NO];
    [[self btForceDL] setHidden:YES];
    [[self btGetEmails] setHidden:YES];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:REMOTE_PACKAGE_URL]];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self pvProgress] setProgress:(float) [downloadProgress fractionCompleted]];
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if(!error) {
            NSLog(@"File downloaded to: %@", filePath);
            
            [SSZipArchive unzipFileAtPath:[filePath path] toDestination:[[filePath path] stringByDeletingLastPathComponent] progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self pvProgress] setProgress:(double)entryNumber / (double)total];
                });
            } completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
                if(succeeded) {
                    mBlock = NO;
                    [self nextScreen:NO];
                }
                else {
                    ////////////////////
                    [SVProgressHUD showErrorWithStatus:@"Echec de la décompression."];
                    [[self btForceDL] setHidden:NO];
                    [[self btGetEmails] setHidden:NO];
                }
            }];
        }
        else {
            //////////////
            [SVProgressHUD showErrorWithStatus:@"Echec du téléchargement."];
            [[self btForceDL] setHidden:NO];
            [[self btGetEmails] setHidden:NO];
        }
    } ];
    [downloadTask resume];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end