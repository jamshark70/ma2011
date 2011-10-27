~addSel = if(SynthDef.findRespondingMethodFor(\add).notNil) { \add } { \memStore };

SynthDef(\keys, { |gateThresh = 0.1995 /* -14.dbamp */, thresh = 0.15|
	var	in = CompanderD.ar(SoundIn.ar(0), gateThresh, slopeBelow: 10, slopeAbove: 1),
	fft = FFT(LocalBuf(512, 1), in),
	trig = Onsets.kr(fft, thresh);
	SendReply.kr(trig, '/keystroke');
}).perform(~addSel);

SynthDef(\masterLimiter, {
	ReplaceOut.ar(0, Limiter.ar(In.ar(0, 2)));
}).perform(~addSel);

SynthDef(\aps, { |out, bufnum, t_trig = 0, gate = 1, attack = 0.01, susLev = 1, release = 0.5,
	start = 0, rate = 1, amp = 0.1, dcyMul = 1, apdecay = 1, topaplevel = 0.25, drylev = 1,
	balance = 0|
	var sig = Normalizer.ar(PlayBuf.ar(1, bufnum, startPos: start, rate: rate, loop: 1), 0.9),
	sum = 0,
	delayscale = MouseX.kr(1, 0.08, lag: 0.1),
	aplevel = MouseY.kr(0, topaplevel, lag: 0.1),
	// transfer function to fade in the allpasses at different rates
	apEnvs = Array.fill(3, { |i|
		InterplEnv(#[0, 0, 1], [i/3, 1/3], \sin)
	}),
	sensitivity = 1 - min(1, Decay2.kr(t_trig, 0.01, TRand.kr(1.0, 6.0, t_trig) * dcyMul)),
	eg = EnvGen.kr(Env.asr(attack, susLev, release, #[4, -4]), gate, doneAction: 2);
	3.do { |i|
		var level = IEnvGen.kr(apEnvs[i], aplevel);
		sum = sum + AllpassL.ar(if(i == 0) { sig } { sum },
			maxdelaytime: 0.1,
			delaytime: LFNoise1.kr(
				{ Rand(2.0, 5.0) }.dup,
				{ Rand(0.02, 0.038) }.dup * delayscale,
				{ Rand(0.04, 0.05) }.dup * delayscale
			),
			decaytime: apdecay,
			mul: (level - 1) * sensitivity + 1
		);
	};
	sum = Balance2.ar(sum[0], sum[1], balance);
	sig = LeakDC.ar(sig * drylev + sum);
	Out.ar(out, sig * eg * amp)
}).perform(~addSel);


SynthDef(\combs, { |out, bufnum, t_trig = 0, gate = 1, attack = 0.01, susLev = 1, release = 0.5,
	start = 0, rate = 1, amp = 0.1, dcyMul = 1, apdecay = 1, topaplevel = 0.25, drylev = 1,
	balance = 0|
	var sig = Normalizer.ar(PlayBuf.ar(1, bufnum, startPos: start, rate: rate, loop: 1), 0.9),
	sum = 0,
	delayscale = MouseX.kr(1, 0.08, lag: 0.1),
	aplevel = MouseY.kr(0, topaplevel, lag: 0.1),
	// transfer function to fade in the allpasses at different rates
	apEnvs = Array.fill(3, { |i|
		InterplEnv(#[0, 0, 1], [i/3, 1/3], \sin)
	}),
	sensitivity = 1 - min(1, Decay2.kr(t_trig, 0.01, TRand.kr(1.0, 6.0, t_trig) * dcyMul)),
	eg = EnvGen.kr(Env.asr(attack, susLev, release, #[4, -4]), gate, doneAction: 2);
	3.do { |i|
		var level = IEnvGen.kr(apEnvs[i], aplevel);
		sum = sum + AllpassL.ar(if(i == 0) { sig } { sum },
			maxdelaytime: 0.1,
			delaytime: LFNoise1.kr(
				{ Rand(2.0, 5.0) }.dup,
				{ Rand(0.02, 0.038) }.dup * delayscale,
				{ Rand(0.04, 0.05) }.dup * delayscale
			),
			decaytime: apdecay,
			mul: (level - 1) * sensitivity + 1
		);
	};
	sum = Balance2.ar(sum[0], sum[1], balance);
	sig = LeakDC.ar(sig * drylev + sum);
	sig = Limiter.ar(sig * amp, 0.9);
	Out.ar(out, sig * eg)
}).perform(~addSel);
