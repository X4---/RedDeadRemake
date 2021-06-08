[numthreads( 8 ,  8 , 1)]
void RenderTransmittanceLutCS(uint3 ThreadId : SV_DispatchThreadID)
{
	float2 PixPos = float2(ThreadId.xy) + 0.5f;


    //SkyAtmosphere_TransmittanceLutSizeAndInvSize = [256, 64, 0.00391 = 1/256, 0.01563]
    //描述对应的这一张LUT贴图的大小 256 * 64

	float2 UV = (PixPos) * SkyAtmosphere_TransmittanceLutSizeAndInvSize.zw;
	float ViewHeight;
	float ViewZenithCosAngle;


    //0.对应的第一个步骤，获取每一个UV 对应的高度，以及ViewZenithCosAngle
    //如果是我的第一个思路，线性均分， 将对应的Viewheight = height / [min,max]
    //对应的轴角，为从地球球心朝着地外的垂直向量， 对应的theta = [0,PI] //[重合， 反向重合] 均分theta，还是均分costhea？ 均分Costheta
    //线性的情况下，Height = lerp( min, max, UV.y) 使用UV.y 作为高度的切分              [v.0]:地表， [v.1]:大气顶
    //线性的情况下，ViewZenithCosAngle = lerp( -1, 1, UV.x) UV.x 作为角度的切分         [u.0]       [u.1]
	UvToLutTransmittanceParams(ViewHeight, ViewZenithCosAngle, UV);


	float3 WorldPos = float3(0.0f, 0.0f, ViewHeight);
	float3 WorldDir = float3(0.0f, sqrt(1.0f - ViewZenithCosAngle * ViewZenithCosAngle), ViewZenithCosAngle);

	SamplingSetup Sampling = (SamplingSetup)0;
	{
		Sampling.VariableSampleCount = false;
		Sampling.SampleCountIni = SkyAtmosphere_TransmittanceSampleCount;
	}
	const bool Ground = false;
	const float DeviceZ =  ( 1 ? 0.0f : 1.0f) ;
	const bool MieRayPhase = false;
	const float3 NullLightDirection = float3(0.0f, 0.0f, 1.0f);
	const float3 NullLightIlluminance = float3(0.0f, 0.0f, 0.0f);
	const float AerialPespectiveViewDistanceScale = 1.0f;
	SingleScatteringResult ss = IntegrateSingleScatteredLuminance(
		float4(PixPos,0.0f,1.0f), WorldPos, WorldDir,
		Ground, Sampling, DeviceZ, MieRayPhase,
		NullLightDirection, NullLightDirection, NullLightIlluminance, NullLightIlluminance,
		AerialPespectiveViewDistanceScale);

	float3 transmittance = exp(-ss.OpticalDepth);

	TransmittanceLutUAV[int2(PixPos)] = transmittance;
}

//0.Function 实际的UV到 ViewHeight， 以及 ViewZenithCosAngle 的映射规则
void UvToLutTransmittanceParams(out float ViewHeight, out float ViewZenithCosAngle, in float2 UV)
{

	float Xmu = UV.x;
	float Xr = UV.y;     

    //Default
    //Atmosphere_TopRadiusKm 6420       Unit : km  地球的大气层的半径
    //Atmosphere_BottomRadiusKm 6360    Unit : km  地球的平均半径


    //H : 对应的地面和大气相切的长度
	float H = sqrt(Atmosphere_TopRadiusKm * Atmosphere_TopRadiusKm - Atmosphere_BottomRadiusKm * Atmosphere_BottomRadiusKm);
	float Rho = H * Xr;
	ViewHeight = sqrt(Rho * Rho + Atmosphere_BottomRadiusKm * Atmosphere_BottomRadiusKm);

    //-地表和大气顶层垂直， 在对应的平面上构成了一个三角形，同时有 H^2 + Ground^2 = Top^2
    //将其中的H 切分进行分段 ， 拆分成 H * Xr 的各个片段，即在H的线上选择多个UV分块的点
    //将H上UV 分块的点和垂直的 Ground 构成三角形，在切线段上构成的地心到切线段上划分的点所构成的新的高度作为ViewHegiht
    //key：将地表到天空切线段上进行高度点进行线性均分， 自己初始的想法：将地表到天空的垂直距离上进行线性均分
    
    //ViewHeight ： 0，地表， 1 ：大气顶层的高度， 对应的线性均分来自于切线

    //对应的 D 描述了 当前刚度到大气的距离 ， 其中存在最小以及最大的值， 
    //最小值为当前高度到大气顶，
    //最大值为当前高度切方向大地表面射出大气。
    //所以一种距离就对应了一个角度。
	float Dmin = Atmosphere_TopRadiusKm - ViewHeight;
	float Dmax = Rho + H;
	float D = Dmin + Xmu * (Dmax - Dmin);

    // D = Dmin * (1 - Xmu) + Xmu * Dmax


	ViewZenithCosAngle = D == 0.0f ? 1.0f : (H * H - Rho * Rho - D * D) / (2.0f * ViewHeight * D);
	ViewZenithCosAngle = clamp(ViewZenithCosAngle, -1.0f, 1.0f);


    //对应的ViewZenithCosAngle 相关的推导参考图

}