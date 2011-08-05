//
//  FBWorkerManager.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FBWorkerQueue.h"
#import "FBWorker.h"

// TODO: TIMEOUT?


//------------------------------------------------------------------------------

@protocol FBWorkerManagerDelegate <NSObject>
@optional
// called in main thread
- (BOOL)canWorkerManagerRun;
- (void)willBeginWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker;
- (void)didUpdateWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker;
- (void)didFinishWorkerManager:(FBWorkerManager*)workerManager worker:(id <FBWorker>)worker;

@end


//------------------------------------------------------------------------------

typedef enum {
    FBWorkerManagerStateStopping = 0,
    FBWorkerManagerStateRunning,
    FBWorkerManagerStateSuspending,
} FBWorkerManagerState;


@interface FBWorkerManager : NSObject

// API (properties)
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, assign) id <FBWorkerManagerDelegate> delegate;
@property (nonatomic, assign) NSUInteger maxWorkers;


// API (properties, readonly)
@property (assign, readonly) FBWorkerManagerState state;
@property (nonatomic, retain, readonly) id <FBWorkerQueue> workerQueue;


// API (general)
+ (FBWorkerManager*)workerManagerWithWorkerQueue:(id <FBWorkerQueue>)workerQueue;
- (void)start;
- (void)stop;
+ (void)enableBackgroundTask;


// API (called by workers)
- (void)notifyUpdatedWorker:(id <FBWorker>)worker;


// API (manage workers)
- (void)suspendAll;
- (void)resumeAll;
- (void)cancelAll;
- (void)cancelWorker:(id <FBWorker>)worker;
- (void)suspendWorker:(id <FBWorker>)worker;
- (void)resumeWorker:(id <FBWorker>)worker;


@end
