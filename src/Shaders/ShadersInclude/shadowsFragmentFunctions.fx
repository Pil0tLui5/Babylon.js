#ifdef SHADOWS
	#ifndef SHADOWFLOAT
		float unpack(vec4 color)
		{
			const vec4 bit_shift = vec4(1.0 / (255.0 * 255.0 * 255.0), 1.0 / (255.0 * 255.0), 1.0 / 255.0, 1.0);
			return dot(color, bit_shift);
		}
	#endif

	float computeShadowCube(vec3 lightPosition, samplerCube shadowSampler, float darkness, vec2 depthValues)
	{
		vec3 directionToLight = vPositionW - lightPosition;
		float depth = length(directionToLight);
		depth = (depth + depthValues.x) / (depthValues.y);
		depth = clamp(depth, 0., 1.0);

		directionToLight = normalize(directionToLight);
		directionToLight.y = -directionToLight.y;
		
		#ifndef SHADOWFLOAT
			float shadow = unpack(textureCube(shadowSampler, directionToLight));
		#else
			float shadow = textureCube(shadowSampler, directionToLight).x;
		#endif

		if (depth > shadow)
		{
			return darkness;
		}
		return 1.0;
	}

	float computeShadowWithPoissonSamplingCube(vec3 lightPosition, samplerCube shadowSampler, float mapSize, float darkness, vec2 depthValues)
	{
		vec3 directionToLight = vPositionW - lightPosition;
		float depth = length(directionToLight);
		depth = (depth + depthValues.x) / (depthValues.y);
		depth = clamp(depth, 0., 1.0);

		directionToLight = normalize(directionToLight);
		directionToLight.y = -directionToLight.y;

		float visibility = 1.;

		vec3 poissonDisk[4];
		poissonDisk[0] = vec3(-1.0, 1.0, -1.0);
		poissonDisk[1] = vec3(1.0, -1.0, -1.0);
		poissonDisk[2] = vec3(-1.0, -1.0, -1.0);
		poissonDisk[3] = vec3(1.0, -1.0, 1.0);

		// Poisson Sampling

		#ifndef SHADOWFLOAT
			if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[0] * mapSize)) < depth) visibility -= 0.25;
			if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[1] * mapSize)) < depth) visibility -= 0.25;
			if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[2] * mapSize)) < depth) visibility -= 0.25;
			if (unpack(textureCube(shadowSampler, directionToLight + poissonDisk[3] * mapSize)) < depth) visibility -= 0.25;
		#else
			if (textureCube(shadowSampler, directionToLight + poissonDisk[0] * mapSize).x < depth) visibility -= 0.25;
			if (textureCube(shadowSampler, directionToLight + poissonDisk[1] * mapSize).x < depth) visibility -= 0.25;
			if (textureCube(shadowSampler, directionToLight + poissonDisk[2] * mapSize).x < depth) visibility -= 0.25;
			if (textureCube(shadowSampler, directionToLight + poissonDisk[3] * mapSize).x < depth) visibility -= 0.25;
		#endif

		return  min(1.0, visibility + darkness);
	}

	float computeShadowWithESMCube(vec3 lightPosition, samplerCube shadowSampler, float darkness, float depthScale, vec2 depthValues)
	{
		vec3 directionToLight = vPositionW - lightPosition;
		float depth = length(directionToLight);
		depth = (depth + depthValues.x) / (depthValues.y);
		float shadowPixelDepth = clamp(depth, 0., 1.0);

		directionToLight = normalize(directionToLight);
		directionToLight.y = -directionToLight.y;
		
		#ifndef SHADOWFLOAT
			float shadowMapSample = unpack(textureCube(shadowSampler, directionToLight));
		#else
			float shadowMapSample = textureCube(shadowSampler, directionToLight).x;
		#endif

		float esm = 1.0 - clamp(exp(min(87., depthScale * shadowPixelDepth)) * shadowMapSample, 0., 1. - darkness);	
		return esm;
	}

	float computeShadowWithCloseESMCube(vec3 lightPosition, samplerCube shadowSampler, float darkness, float depthScale, vec2 depthValues)
	{
		vec3 directionToLight = vPositionW - lightPosition;
		float depth = length(directionToLight);
		depth = (depth + depthValues.x) / (depthValues.y);
		float shadowPixelDepth = clamp(depth, 0., 1.0);

		directionToLight = normalize(directionToLight);
		directionToLight.y = -directionToLight.y;
		
		#ifndef SHADOWFLOAT
			float shadowMapSample = unpack(textureCube(shadowSampler, directionToLight));
		#else
			float shadowMapSample = textureCube(shadowSampler, directionToLight).x;
		#endif

		float esm = clamp(exp(min(87., -depthScale * (shadowPixelDepth - shadowMapSample))), darkness, 1.);

		return esm;
	}

	float computeShadow(vec4 vPositionFromLight, float depthMetric, sampler2D shadowSampler, float darkness, float frustumEdgeFalloff)
	{
		vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
		vec2 uv = 0.5 * clipSpace.xy + vec2(0.5);

		if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)
		{
			return 1.0;
		}

		float shadowPixelDepth = clamp(depthMetric, 0., 1.0);

		#ifndef SHADOWFLOAT
			float shadow = unpack(texture2D(shadowSampler, uv));
		#else
			float shadow = texture2D(shadowSampler, uv).x;
		#endif

		if (shadowPixelDepth > shadow)
		{
			return computeFallOff(darkness, clipSpace.xy, frustumEdgeFalloff);
		}
		return 1.;
	}

	float computeShadowWithPoissonSampling(vec4 vPositionFromLight, float depthMetric, sampler2D shadowSampler, float mapSize, float darkness, float frustumEdgeFalloff)
	{
		vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
		vec2 uv = 0.5 * clipSpace.xy + vec2(0.5);

		if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)
		{
			return 1.0;
		}

		float shadowPixelDepth = clamp(depthMetric, 0., 1.0);

		float visibility = 1.;

		vec2 poissonDisk[4];
		poissonDisk[0] = vec2(-0.94201624, -0.39906216);
		poissonDisk[1] = vec2(0.94558609, -0.76890725);
		poissonDisk[2] = vec2(-0.094184101, -0.92938870);
		poissonDisk[3] = vec2(0.34495938, 0.29387760);

		// Poisson Sampling

		#ifndef SHADOWFLOAT
			if (unpack(texture2D(shadowSampler, uv + poissonDisk[0] * mapSize)) < shadowPixelDepth) visibility -= 0.25;
			if (unpack(texture2D(shadowSampler, uv + poissonDisk[1] * mapSize)) < shadowPixelDepth) visibility -= 0.25;
			if (unpack(texture2D(shadowSampler, uv + poissonDisk[2] * mapSize)) < shadowPixelDepth) visibility -= 0.25;
			if (unpack(texture2D(shadowSampler, uv + poissonDisk[3] * mapSize)) < shadowPixelDepth) visibility -= 0.25;
		#else
			if (texture2D(shadowSampler, uv + poissonDisk[0] * mapSize).x < shadowPixelDepth) visibility -= 0.25;
			if (texture2D(shadowSampler, uv + poissonDisk[1] * mapSize).x < shadowPixelDepth) visibility -= 0.25;
			if (texture2D(shadowSampler, uv + poissonDisk[2] * mapSize).x < shadowPixelDepth) visibility -= 0.25;
			if (texture2D(shadowSampler, uv + poissonDisk[3] * mapSize).x < shadowPixelDepth) visibility -= 0.25;
		#endif

		return computeFallOff(min(1.0, visibility + darkness), clipSpace.xy, frustumEdgeFalloff);
	}

	float computeShadowWithESM(vec4 vPositionFromLight, float depthMetric, sampler2D shadowSampler, float darkness, float depthScale, float frustumEdgeFalloff)
	{
		vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
		vec2 uv = 0.5 * clipSpace.xy + vec2(0.5);

		if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)
		{
			return 1.0;
		}

		float shadowPixelDepth = clamp(depthMetric, 0., 1.0);

		#ifndef SHADOWFLOAT
			float shadowMapSample = unpack(texture2D(shadowSampler, uv));
		#else
			float shadowMapSample = texture2D(shadowSampler, uv).x;
		#endif
		
		float esm = 1.0 - clamp(exp(min(87., depthScale * shadowPixelDepth)) * shadowMapSample, 0., 1. - darkness);

		return computeFallOff(esm, clipSpace.xy, frustumEdgeFalloff);
	}

	float computeShadowWithCloseESM(vec4 vPositionFromLight, float depthMetric, sampler2D shadowSampler, float darkness, float depthScale, float frustumEdgeFalloff)
	{
		vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
		vec2 uv = 0.5 * clipSpace.xy + vec2(0.5);

		if (uv.x < 0. || uv.x > 1.0 || uv.y < 0. || uv.y > 1.0)
		{
			return 1.0;
		}

		float shadowPixelDepth = clamp(depthMetric, 0., 1.0);		
		
		#ifndef SHADOWFLOAT
			float shadowMapSample = unpack(texture2D(shadowSampler, uv));
		#else
			float shadowMapSample = texture2D(shadowSampler, uv).x;
		#endif
		
		float esm = clamp(exp(min(87., -depthScale * (shadowPixelDepth - shadowMapSample))), darkness, 1.);

		return computeFallOff(esm, clipSpace.xy, frustumEdgeFalloff);
	}

	#ifdef WEBGL2
		const vec3 PCFSamplers[32] = vec3[32](
			vec3(0.06407013, 0.05409927, 0.),
			vec3(0.7366577, 0.5789394, 0.),
			vec3(-0.6270542, -0.5320278, 0.),
			vec3(-0.4096107, 0.8411095, 0.),
			vec3(0.6849564, -0.4990818, 0.),
			vec3(-0.874181, -0.04579735, 0.),
			vec3(0.9989998, 0.0009880066, 0.),
			vec3(-0.004920578, -0.9151649, 0.),
			vec3(0.1805763, 0.9747483, 0.),
			vec3(-0.2138451, 0.2635818, 0.),
			vec3(0.109845, 0.3884785, 0.),
			vec3(0.06876755, -0.3581074, 0.),
			vec3(0.374073, -0.7661266, 0.),
			vec3(0.3079132, -0.1216763, 0.),
			vec3(-0.3794335, -0.8271583, 0.),
			vec3(-0.203878, -0.07715034, 0.),
			vec3(0.5912697, 0.1469799, 0.),
			vec3(-0.88069, 0.3031784, 0.),
			vec3(0.5040108, 0.8283722, 0.),
			vec3(-0.5844124, 0.5494877, 0.),
			vec3(0.6017799, -0.1726654, 0.),
			vec3(-0.5554981, 0.1559997, 0.),
			vec3(-0.3016369, -0.3900928, 0.),
			vec3(-0.5550632, -0.1723762, 0.),
			vec3(0.925029, 0.2995041, 0.),
			vec3(-0.2473137, 0.5538505, 0.),
			vec3(0.9183037, -0.2862392, 0.),
			vec3(0.2469421, 0.6718712, 0.),
			vec3(0.3916397, -0.4328209, 0.),
			vec3(-0.03576927, -0.6220032, 0.),
			vec3(-0.04661255, 0.7995201, 0.),
			vec3(0.4402924, 0.3640312, 0.)
		);

		// Shadow PCF kernel size 1 with a single tap (lowest quality)
		float computeShadowWithPCF1(vec4 vPositionFromLight, sampler2DShadow shadowSampler, float darkness, float frustumEdgeFalloff)
		{
			vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
			vec3 uvDepth = vec3(0.5 * clipSpace.xyz + vec3(0.5));

			float shadow = texture2D(shadowSampler, uvDepth);
			shadow = shadow * (1. - darkness) + darkness;
			return computeFallOff(shadow, clipSpace.xy, frustumEdgeFalloff);
		}

		// Shadow PCF kernel 3*3 in only 4 taps (medium quality)
		// This uses a well distributed taps to allow a gaussian distribution covering a 3*3 kernel
		// https://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
		float computeShadowWithPCF3(vec4 vPositionFromLight, sampler2DShadow shadowSampler, vec2 shadowMapSizeAndInverse, float darkness, float frustumEdgeFalloff)
		{
			vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
			vec3 uvDepth = vec3(0.5 * clipSpace.xyz + vec3(0.5));

			vec2 uv = uvDepth.xy * shadowMapSizeAndInverse.x;	// uv in texel units
			uv += 0.5;											// offset of half to be in the center of the texel
			vec2 st = fract(uv);								// how far from the center
			vec2 base_uv = floor(uv) - 0.5;						// texel coord
			base_uv *= shadowMapSizeAndInverse.y;				// move back to uv coords

			// Equation resolved to fit in a 3*3 distribution like 
			// 1 2 1
			// 2 4 2 
			// 1 2 1
			vec2 uvw0 = 3. - 2. * st;
			vec2 uvw1 = 1. + 2. * st;
			vec2 u = vec2((2. - st.x) / uvw0.x - 1., st.x / uvw1.x + 1.) * shadowMapSizeAndInverse.y;
			vec2 v = vec2((2. - st.y) / uvw0.y - 1., st.y / uvw1.y + 1.) * shadowMapSizeAndInverse.y;

			float shadow = 0.;
			shadow += uvw0.x * uvw0.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[0], v[0]), uvDepth.z));
			shadow += uvw1.x * uvw0.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[1], v[0]), uvDepth.z));
			shadow += uvw0.x * uvw1.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[0], v[1]), uvDepth.z));
			shadow += uvw1.x * uvw1.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[1], v[1]), uvDepth.z));
			shadow = shadow / 16.;

			shadow = shadow * (1. - darkness) + darkness;
			return computeFallOff(shadow, clipSpace.xy, frustumEdgeFalloff);
		}
		
		// Shadow PCF kernel 5*5 in only 9 taps (high quality)
		// This uses a well distributed taps to allow a gaussian distribution covering a 5*5 kernel
		// https://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
		float computeShadowWithPCF5(vec4 vPositionFromLight, sampler2DShadow shadowSampler, vec2 shadowMapSizeAndInverse, float darkness, float frustumEdgeFalloff)
		{
			vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
			vec3 uvDepth = vec3(0.5 * clipSpace.xyz + vec3(0.5));

			vec2 uv = uvDepth.xy * shadowMapSizeAndInverse.x;	// uv in texel units
			uv += 0.5;											// offset of half to be in the center of the texel
			vec2 st = fract(uv);								// how far from the center
			vec2 base_uv = floor(uv) - 0.5;						// texel coord
			base_uv *= shadowMapSizeAndInverse.y;				// move back to uv coords

			// Equation resolved to fit in a 5*5 distribution like 
			// 1 2 4 2 1
			vec2 uvw0 = 4. - 3. * st;
			vec2 uvw1 = vec2(7.);
			vec2 uvw2 = 1. + 3. * st;

			vec3 u = vec3((3. - 2. * st.x) / uvw0.x - 2., (3. + st.x) / uvw1.x, st.x / uvw2.x + 2.) * shadowMapSizeAndInverse.y;
			vec3 v = vec3((3. - 2. * st.y) / uvw0.y - 2., (3. + st.y) / uvw1.y, st.y / uvw2.y + 2.) * shadowMapSizeAndInverse.y;

			float shadow = 0.;
			shadow += uvw0.x * uvw0.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[0], v[0]), uvDepth.z));
			shadow += uvw1.x * uvw0.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[1], v[0]), uvDepth.z));
			shadow += uvw2.x * uvw0.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[2], v[0]), uvDepth.z));
			shadow += uvw0.x * uvw1.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[0], v[1]), uvDepth.z));
			shadow += uvw1.x * uvw1.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[1], v[1]), uvDepth.z));
			shadow += uvw2.x * uvw1.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[2], v[1]), uvDepth.z));
			shadow += uvw0.x * uvw2.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[0], v[2]), uvDepth.z));
			shadow += uvw1.x * uvw2.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[1], v[2]), uvDepth.z));
			shadow += uvw2.x * uvw2.y * texture2D(shadowSampler, vec3(base_uv.xy + vec2(u[2], v[2]), uvDepth.z));
			shadow = shadow / 144.;

			shadow = shadow * (1. - darkness) + darkness;
			return computeFallOff(shadow, clipSpace.xy, frustumEdgeFalloff);
		}

		float computeShadowWithPCSS(vec4 vPositionFromLight, sampler2D depthSampler, sampler2DShadow shadowSampler, vec2 shadowMapSizeAndInverse, float darkness, float frustumEdgeFalloff)
		{
			vec3 clipSpace = vPositionFromLight.xyz / vPositionFromLight.w;
			vec3 uvDepth = vec3(0.5 * clipSpace.xyz + vec3(0.5));

			float softness = 50.;

			float searchSize = softness * clamp(uvDepth.z - .02, 0., 1.) / uvDepth.z;

			float blockerDepth = 0.0;
			float sumBlockerDepth = 0.0;
			float numBlocker = 0.0;
			for (int i = 0; i < 16; i++) {
                blockerDepth = texture(depthSampler, uvDepth.xy + (searchSize * shadowMapSizeAndInverse.y * PCFSamplers[i].xy)).r;
                if (blockerDepth < uvDepth.z) {
                    sumBlockerDepth += blockerDepth;
                    numBlocker++;
                }
            }

			if (numBlocker < 1.0) {
				return 1.0;
			}

			float avgBlockerDepth = sumBlockerDepth / numBlocker;
			float penumbra = uvDepth.z - avgBlockerDepth;
			float filterRadiusUV = penumbra * softness;

			float shadow = 0.;

			float random = getRand(gl_FragCoord.xy / 1024.);
			float rotationAngle = random * 3.1415926;
			vec2 rotationTrig = vec2(cos(rotationAngle), sin(rotationAngle));

			for (int i = 0; i < 32; i++) {
				vec3 offset = PCFSamplers[i];

				offset = vec3(offset.x * rotationTrig.x - offset.y * rotationTrig.y, offset.y * rotationTrig.x + offset.x * rotationTrig.y, 0.);

				shadow += texture2D(shadowSampler, uvDepth + offset * filterRadiusUV * shadowMapSizeAndInverse.y);
			}
			shadow /= 32.;

			shadow = shadow * (1. - darkness) + darkness;
			return computeFallOff(shadow, clipSpace.xy, frustumEdgeFalloff);
		}
	#endif
#endif
