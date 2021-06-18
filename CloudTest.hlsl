struct Fow
{
    

    //Input float3 CameraPosition
    //Input float3 CameraToWordPositionDir
    //Input float PerStepContribute
    //Input float2 NoiseTextureWidth
    //Input Texture NoiseTexture
    //Input float NoiseSatureValue
    //Input float SceneDepth
    //Input Texture BasicCloudShapeTexture82
    //Input Texture HeightCloudShapeLutTexture81
    float GetCloudDensity()
    {
        float PerStepLength = 1000;
        float total = 0;

        float3 NormalCameraDir = normalize(CameraToWordPositionDir);
        bool bIsSky = SceneDepth > 1642100/2;
        float3 TargetPosition = SceneDepth * NormalCameraDir + CameraPosition;

        //160 * 100 * 10
        bIsSky = bIsSky | TargetPosition.z >= 160000;
        float FixSceneZ = SceneDepth/1000;

        if(bIsSky)
        {
            float absViewZ = abs(NormalCameraDir);

            //Transfer WorldPosition In cm to WorldPosition in 10m
            float3 FixCameraPosition = CameraPosition/1000;
            float3 Center = float3(2147.30591, -909.29419, - 318000.0f);

            float TopAtmosphere = 318000.0f + 1240;
            float3 ViewPosToCenter = FixCameraPosition - Center;

            float _383 = dot(NormalCameraDir,NormalCameraDir);
            float _384 = dot(ViewPosToCenter,ViewPosToCenter);

            float _385 = 2.0*_384;

            float deltaMatrix = (_385 * _385) - (
                                        (4.0f * _383) * (
                                                            dot(ViewPosToCenter, ViewPosToCenter) - (TopAtmosphere * TopAtmosphere)
                                                        )
                                                );


            float2 distanceIntersectAtmosphere;
            if(deltaMatrix< 0.0f)
            {
                distanceIntersectAtmosphere = (-1.0f).xx;

            }else{

                float _397 = sqrt(deltaMatrix);
                float _398 = _384*(-2.0f);
                //(-b +- (delta)^1/2)  / 2a
                distanceIntersectAtmosphere = float2( _398 - _397, _398 + _397) / (2.0f * _383).xx;
            }

        
            float MaxIntersectDistance = min(FixSceneZ ,max(distanceIntersectAtmosphere.x, distanceIntersectAtmosphere.y));

            if(NormalCameraDir.z < 0.0)
            {
                MaxIntersectDistance = min(
                                            MaxIntersectDistance, 
                                            (FixCameraPosition.z +57)/
                                            (max(-CameraToWordPositionDir.z, 0.0000001))
                                            );
            }

            MaxIntersectDistance = min(MaxIntersectDistance, 22000);

            float _459 = MaxIntersectDistance - 160;

            float PerStepLength = max(                                   // 单位块的距离
                            _459 / max(                     
                                        8.0f,               // 最小的块数量
                                        round(              // 分块数量 = _459 / 125.0  块距离
                                            _459 / lerp(
                                                        125,                      //对应的云层进行Intersect 距离分块的最小块距离
                                                        125 * 0.5f, 
                                                        clamp(                          //abs ViewDirZ norli
                                                              (absViewZ - 0.5f) * 2.0f, 
                                                                0.0f, 
                                                                1.0f)
                                                        )
                                            )
                                    ), 
                            
                            9.9999999747524270787835121154785e-07f); //0.000001

            float FistRayTracingDistance = 160 + 0.5 * PerStepLength;


            float CurrentRayTracingDistance = FistRayTracingDistance;
            float RemainTransmittance = 1.0f;

            int currentstep = 0;
            for(  
                    ; 
                    RemainTransmittance > 0.05 &&
                    currentstep < 1000 && 
                    CurrentRayTracingDistance <= MaxIntersectDistance
                    ;
                    
                    ++currentstep
                     )
            {

                float3 Dis = CameraToWordPositionDir * CurrentRayTracingDistance;
                float3 TargetCheckPoint = FixCameraPosition + Dis;


                float CheckPointHeightModifyParam = clamp(
                                    (
                                        (length(TargetCheckPoint - Center) - 318000.0f) - 200       // CheckPointWorldPosition - SphereCenter - 318000,  ModifyCheckPointHeight  - _77_m27.x
                                    ) * 0.00076923076994717121124267578125f,                // * 1/1300
                                    0.0f, 
                                    1.0f
                                );


                float3 BasicCloudDisUVOffset = float3(293.729, 271.52029,0) * CheckPointHeightModifyParam;
                float3 BasicCloudDisUVPos = TargetCheckPoint + BasicCloudDisUVOffset;

                float2 BasicCloudSampleUV = BasicCloudDisUVPos * 0.00003 + 0.5;

                float4 BasicCloudSampleValue = BasicCloudShapeTexture82.SampleLevle(
                    BasicCloudShapeTexture82Sampler,
                    BasicCloudSampleUV,
                    0.0f
                );


                CheckPointHeightModifyParam = max(0,CheckPointHeightModifyParam - BasicCloudSampleValue.z);

                float SampleCloudDensity = 0.0f;
                float SampleCloudLutW = 0.0f;

                [branch]
                if(true && (CheckPointHeightModifyParam > 0.0f))
                {
                    float4 HeightCloudShapeLutSampleValue = HeightCloudShapeLutTexture81.SampleLevel(
                        HeightCloudShapeLutTexture81Sampler,
                        float2(0.0, CheckPointHeightModifyParam)
                    );


                    float4 globalCloudshape = float4(0.09314, 0.50, 0.00, 0.59766);

                    float2 TempShapdeValue = 1.0 - HeightCloudShapeLutSampleValue.xy;
                    SampleCloudLutW = HeightCloudShapeLutSampleValue.w;
                    SampleCloudDensity = min(
                                            1.0f,
                                            dot(
                                                float2(1.0f, HeightCloudShapeLutSampleValue.z),
                                                smoothstep(
                                                        globalCloudshape.xz + TempShapdeValue,
                                                        globalCloudshape.zw + TempShapdeValue,
                                                        BasicCloudSampleValue.xy
                                                ).xy
                                            ));

                }else
                {
                    SampleCloudDensity = 0.0f;
                    SampleCloudLutW = 0.0f;
                }


                bool BEnough = SampleCloudDensity >
                                ( 0.2 *
                                    min(
                                        clamp(
                                                (MaxIntersectDistance - CurrentRayTracingDistance) * 0.00001,
                                                0.0f,
                                                1.0f
                                        ),

                                        1.0 - clamp(
                                                absViewZ * 1.33,
                                                0.0f,
                                                1.0f
                                            )
                                        )
                                );
                                
                if(BEnough)
                {
                    return SampleCloudDensity;
                    break;
                }

                

            }


            return MaxIntersectDistance;
        }
        
        return 1;
    }

    

    float ComputeDensity(float3 CheckPointPosition)
    {
        float BottomRadius = 6360000;
        float3 CheckPointPositionInMeter = CheckPointPosition/100;
        float3 SphereCenter = float3(0, 0 , -BottomRadius);

        float ViewHeight = length(CheckPointPositionInMeter - SphereCenter) - BottomRadius;
        float2 TextureSampleUV = frac(CheckPointPosition.xy / NoiseTextureWidth.xy);
        
        float NoiseValue = 1.0 - NoiseTexture.Sample(NoiseTextureSampler, TextureSampleUV, 0).r;

        NoiseValue = NoiseValue * step(NoiseValue, NoiseSatureValue);

        if(ViewHeight >= 200  &&  ViewHeight<=250) 
        {
            return PerStepContribute * NoiseValue;
        }
        return 0;
    }


    float3 ComputeBasicIntersectionPosition(float3 Origin, float3 TargetDir, out float PerStepLength)
    {
        
        PerStepLength = (25000-20000)/abs(TargetDir.z)/ 200;
        PerStepLength = min(PerStepLength, 1000);
        
        if(Origin.z >= 20000 && Origin.z <= 25000)
        {
            return Origin;
        }

        if(abs(TargetDir.z) <= 0.0001)
        {
            return Origin;
        }
        float deltabottom = 25000 - Origin.z;
        float deltaTop = 20000 - Origin.z;

        float Distancebottom = deltabottom/ TargetDir.z;
        float DistanceTop = deltaTop / TargetDir.z;

        float mindistance = min(Distancebottom,DistanceTop);
        mindistance = max(0, mindistance);


        return Origin + mindistance * TargetDir;
    }
};Fow f;
return f.GetCloudDensity();