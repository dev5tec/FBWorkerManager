//
//  FBWorkerSource.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FBWorker.h"

@protocol FBWorkerQueue <NSObject>

// NOTE: must be thread-safe
- (NSUInteger)count;
- (id <FBWorker>)nextWorker;

@end
