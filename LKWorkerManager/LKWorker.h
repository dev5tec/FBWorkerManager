//
//  LKWorker.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LKWorkerManager;
@protocol LKWorker <NSObject>

// return: YES=finished / NO=not finished
- (BOOL)executeOnWorkerManager:(LKWorkerManager*)workerManager;

@optional
- (void)pauseOnWorkerManager:(LKWorkerManager*)workerManager;
- (void)resumeOnWorkerManager:(LKWorkerManager*)workerManager;
- (void)cancelOnWorkerManager:(LKWorkerManager*)workerManager;

@end