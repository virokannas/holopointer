//
//  USDZExporter.h
//  holopointer
//
//  Created by Simo Virokannas on 12/31/20.
//

#ifndef USDZExporter_h
#define USDZExporter_h

#import <SceneKit/SceneKit.h>

@interface USDSwift : NSObject
+ (void) writePointsToFile:(const char *)path points:(const SCNVector3[]) points npoints:(int) npoints ;
@end

#endif /* USDZExporter_h */
