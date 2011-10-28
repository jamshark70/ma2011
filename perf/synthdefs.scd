~addSel = if(SynthDef.findRespondingMethodFor(\add).notNil) { \add } { \memStore };

~ebuf = Buffer.sendCollection(s, Env.perc(0.01, 0.99).asSignal(512));

SynthDef(\keys, { |gateThresh = 0.1995 /* -14.dbamp */, thresh = 0.15|
	var	in = CompanderD.ar(SoundIn.ar(0), gateThresh, slopeBelow: 10, slopeAbove: 1),
	fft = FFT(LocalBuf(512, 1), in),
	trig = Onsets.kr(fft, thresh);
	SendReply.kr(trig, '/keystroke');
}).perform(~addSel);

SynthDef(\masterLimiter, {
	ReplaceOut.ar(0, Limiter.ar(In.ar(0, 2)));
}).perform(~addSel);


SynthDef(\linmap, { |inbus, outbus, inMin, inMax, outMin, outMax|
	ReplaceOut.kr(outbus,
		In.kr(inbus, 1).linlin(inMin, inMax, outMin, outMax)
	);
}).perform(~addSel);

SynthDef(\expmap, { |inbus, outbus, inMin, inMax, outMin, outMax|
	ReplaceOut.kr(outbus,
		In.kr(inbus, 1).linexp(inMin, inMax, outMin, outMax)
	);
}).perform(~addSel);


SynthDef("rvbxfer", {
	arg inbus, outbus, level = 0.1;
	var sig = In.ar(inbus, 2);
	Out.ar(outbus, sig * level);
	Out.ar(0, sig);
}).send(s);

SynthDef(\reverb, { |in, out, earlyDecay = 0.08, decay = 2, earlyAmp = 0.2, tailAmp = 1|
	var sig = In.ar(in, 2),
	early = LeakDC.ar(
		sig.collect { |chan|
			CombL.ar(chan, 0.03, Array.fill(3, { Rand(0.01, 0.03) }), earlyDecay).sum
		}
	),
	tail = sig;
	4.do {
		tail = tail + AllpassL.ar(tail, 0.08, Rand(0.03, 0.08), decay);
	};
	Out.ar(out, (early * earlyAmp) + (tail * tailAmp));
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


~makeLagDef = { |numChan = 1|
	SynthDef("lags" ++ numChan, { |inbus, outbus, lagtime = 0.15|
		var	sig = In.kr(inbus, numChan),
		trigs = HPZ1.kr(sig).abs > 0,
		envs = sig.asArray.collect { |chan, i|
			EnvGen.kr(Env([chan, chan], [lagtime]), trigs[i])
		};
		ReplaceOut.kr(outbus, envs);
	}).perform(topEnvironment[\addSel]);
};

~makeLagDef.(5);


~mappedData = IdentityDictionary.new;
~ctlNums = (x: 0, y: 1, theta: 2, rho: 3, mag: 4, angle: 2, radius: 3, rad: 3, mx: 5, mouseX: 5, my: 6, mouseY: 6);
~map = inEnvir({ |synth, name, ctlName, inMin, inMax, outMin, outMax, curve(\lin), source(~lagbus)|
	var synthmaps, mapping;
	~unmap.(synth, name);
	synthmaps = ~mappedData[synth];
	if(synthmaps.isNil) {
		synthmaps = IdentityDictionary.new;
		~mappedData[synth] = synthmaps;
	};
	synthmaps.put(name, List.new);
	mapping = IdentityDictionary.new;
	mapping[\bus] = Bus.control(s, 1);
	mapping[\ctlname] = ctlName;
	mapping[\mapsynth] = Synth(curve ++ "map",
		[
			inbus: source.index + (~ctlNums[name] ? 0),
			outbus: mapping[\bus]
		] ++ [#[inMin, inMax, outMin, outMax], [inMin, inMax, outMin, outMax]].flop.flat,
		target: s.asTarget, addAction: \addBefore
	);
	mapping[\listener] = Updater(synth, { |node, what|
		if(what == \n_end) {
			mapping[\listener].remove;
			topEnvironment.use { ~unmap.(synth, name) }
		};
	});
	synth.map(ctlName, mapping[\bus]);
	synth.register;
	synthmaps[name].add(mapping);
	mapping
}, topEnvironment);

~unmap = { |synth, name|
	var synthmaps;
	if((synthmaps = ~mappedData[synth]).notNil) {
		synthmaps[name].do { |mapping|
			if(synth.isPlaying) { synth.map(mapping[\ctlname], -1) };
			mapping[\mapsynth].free;
			mapping[\bus].free;
			mapping[\listener].remove;
		};
		synthmaps.removeAt(name);
		if(synthmaps.size == 0) { ~mappedData.removeAt(synth) };
	};
};