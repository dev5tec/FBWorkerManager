//
//  LKWorkerManagerViewController.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LKWorkerManager.h"
#import "Sample.h"
#import "SampleQueue.h"

@interface LKWorkerManagerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, LKWorkerManagerDelegate> {
    UIBarButtonItem *control;
}


@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) SampleQueue* queue;
@property (nonatomic, retain) LKWorkerManager* workerManager;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *cancelButton;

- (IBAction)add:(id)sender;
- (IBAction)pauseAllWorkers:(id)sender;
- (IBAction)resumeAllWorkers:(id)sender;
- (IBAction)cancelAllWorkers:(id)sender;

- (IBAction)suspendResumeWorker:(id)sender event:(UIEvent*)event;
- (IBAction)cancelWorker:(id)sender event:(UIEvent*)event;
@end
