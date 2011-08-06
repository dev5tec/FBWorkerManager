//
//  FBWorkerManagerTests.h
//  FBWorkerManagerTests
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "FBWorkerManager.h"

@interface FBWorkerManagerTests : SenTestCase <FBWorkerManagerSource, FBWorkerManagerDelegate>

@property (nonatomic, retain) FBWorkerManager* workerManager;
@property (nonatomic, retain) NSMutableArray* list;
@property (nonatomic, assign) BOOL canNotRun;
@end
