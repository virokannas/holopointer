//
//  USDZExporter.m
//  holopointer
//
//  Created by Simo Virokannas on 12/31/20.
//

#import "USDZExporter.h"
#import <Foundation/Foundation.h>
#include <pxr/pxr.h>
#include <pxr/usd/usdGeom/xform.h>
#include <pxr/usd/usdGeom/points.h>
#include <pxr/usd/usd/stage.h>
#include <pxr/usd/sdf/layer.h>
#include <pxr/usd/sdf/path.h>
#include <pxr/usd/usdGeom/tokens.h>
#include <pxr/usd/usdGeom/metrics.h>

PXR_NAMESPACE_OPEN_SCOPE

void _internal_writePointsToFile(const SCNVector3 points[], int npoints, const char *path) {
    UsdStageRefPtr stage = UsdStage::CreateNew(path);
    //UsdGeomSetStageUpAxis(stage, TfToken("Y"));
    //auto root = UsdGeomXform::Define(stage, SdfPath("/objects"));
    //UsdModelAPI(root).SetKind(KindTokens->component);
    UsdGeomXform xform = UsdGeomXform::Define(stage, SdfPath("/points"));
    UsdGeomPoints pts = UsdGeomPoints::Define(stage, SdfPath("/points/pts"));
    //GfVec3f *usdPoints = (GfVec3f *)malloc(sizeof(GfVec3f) * npoints);
    VtArray<GfVec3f> usdPoints;
    for(int i=0;i<npoints;i++) {
        const SCNVector3 &p = points[i];
        usdPoints.push_back(GfVec3f(p.x, p.y, p.z));
    }
    pts.CreatePointsAttr().Set(usdPoints);
    stage->GetRootLayer()->Save();
}

PXR_NAMESPACE_CLOSE_SCOPE

@implementation USDSwift {
}
+ (void) writePointsToFile:(const char *)path points:(const SCNVector3[]) points npoints:(int) npoints {
    pxr::_internal_writePointsToFile(points, npoints, path);
}

@end
