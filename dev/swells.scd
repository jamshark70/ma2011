var dir;

if(Func.exists(\ma2011dir)) {
	dir = \ma2011dir.eval;
} {
	Error("Func(\\ma2011dir) doesn't exist. Check your startup configuration (instructions in addToYourStartupFile.scd).").throw;
};

(dir +/+ "perf/loadVideo.scd").loadPath;

s.waitForBoot {

	(PR.filenameSymbol.asString.dirname +/+ "Prototypes/devPreMIDIcfg.scd").loadPath;
	MIDIPort.init(~srcInports);

	\makeEmptyMixer8.eval;

	(
		make: { |name|
			var	out, argnames, argspecs;
			~cb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
				buf.sine1Msg((1..10).reciprocal);
			});
			~mb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
				buf.sine1Msg(#[1]);
			});

			~target = MixerChannel(name, s, 2, 2, level: -14.dbamp);

			// hack: pass gate and mod_vs to mod_env
			WrapInstr("osc2.fm2carpan", { |pan = 0, gate = 1, mod_env, mod_vs = 0|
				mod_env = mod_env.dereference.value(gate, mod_vs);
				Pan2.ar(
					WrapInstr.wrap("osc2.fm2car", [
						nil, gate, nil, mod_env, nil, nil, nil, nil, nil, nil, nil,
						mod_vs
					]),
					pan
				)
			}, [\bipolar, #[0, 1], EnvSpec(Env.one), #[0, 1]]);

			out = Voicer(40, WrapInstr("osc2.fm2carpan"), [
				car_env: Env.adsr(0.8, 0.4, 0.6, 2.8),
				mod_env: `{ |gate|
					// maybe NamedControl for time sensitivity?
					Env([1, gate.linlin(0, 1, 1, 1.6), 1], [gate.linexp(0, 1, 2, 0.2), gate.linexp(0, 1, 3.3, 0.7)])
				},
				car_buf: ~cb, mod_buf: ~mb,
				mod_lev: 1.8037946271776,
				mod_ratio: 4 //,
				// detune: -0.19685039370079,
				// car_detune: 1.0052043765621,
				// car_vs: 0.79527559055118,
				// mod_vs: 0.37795275590551,
				// basefreq: 440,
				// keyscale: 0.33736499154165
			], target: ~target);

			argnames = out.nodes[0].patch.argNames;
			argspecs = IdentityDictionary.new;
			out.nodes[0].patch.argSpecs.do { |spec, i|
				argspecs.put(argnames[i], spec)
			};

			[
				detune: -0.19685039370079,
				car_detune: 1.0052043765621,
				car_vs: 0.79527559055118,
				mod_vs: 0.37795275590551,
				basefreq: 440,
				keyscale: 0.33736499154165,
			].pairsDo { |name, value|
				out.mapGlobal(name, nil, value, argspecs[name]);
			};
			out
		},
		free: { [~target, ~cb, ~mb].free },
		type: \voicer) => Fact(\fmswells);

	if(Mode.exists(\dmixo).not) {
		ModalSpec(#[0, 2, 4, 5, 7, 9, 10], 12, 2) => Mode(\dmixo);
	};

	PR(\abstractProcess).clone({
		~event = (eventKey: \voicerNote, immediateOSC: true);
		~mode = \dmixo;
		~magThresh = 80000;
		// try to make vertical and horizontal work as sonorities
		// only the middle one is cheezy
		~chords = [
			#[21, 25, 28, 31, 33],
			#[28, 31, 32, 36, 40],
			#[29, 33, 34, 37, 42],
			#[31, 36, 37, 40, 46],
			#[34.5, 38, 43, 44, 47]
		];

		~prep = {
			~event.parent = ProtoEvent(\voicerNote).v.parent;
			~resp = SimpleController(~model).put(\allPtsReceived, e {
				~respond.();
			});
			~gridNodes = Array.fill(~model.points.size, nil);
			~makeStreamForKey.(\notePat);
			currentEnvironment
		};

		~freeCleanup = {
			~resp.remove;
		};

		~freq = Pfunc({ |ev| ~chords[4 - (ev[\i] % 5)][ev[\i] div: 5] });
		~delta = 1;
		~length = Pfunc({ |ev| ~model.points[ev[\i]].mag.last.linlin(20000, 300000, 2.5, 0.6) });
		~gate = Pfunc({ |ev| ~model.points[ev[\i]].mag.last.linlin(20000, 300000, 0.02, 0.15) });
		~pan = Pkey(\i).linlin(0, 24, -0.9, 0.9);

		~notePat = Pbind(
			\freq, BPStream(\freq),
			\mode, BPStream(\mode),
			\delta, BPStream(\delta),
			\length, BPStream(\length),
			\gate, BPStream(\gate),
			\pan, BPStream(\pan)
		);

		~respond = {
			var ind = ~gridNodes.collectIndicesOfItem(nil),
			pts, ev;
			if(ind.size > 0) {
				pts = [ind, ~model.points[ind]].flop
				.sort { |a, b| a[1].mag.last > b[1].mag.last };
				if(pts[0][1].mag.last >= ~magThresh) {
					ind = pts[0][0];
					ev = ~notePatStream.next(~event.copy.put(\i, ind)).play;
					pts = nil;
					~gridNodes[ind] = ev.nodes[0];
					OSCFunc(OSCArgsMatcher([ev.nodes[0].synth.nodeID], e {
						~gridNodes[ind] = nil;  // free up to play again
					}), '/n_end', s.addr).oneShot;
				};
			};
		};
	}) => PR(\swellTrig);

	VC(\fms).free;
	Fact(\fmswells) => VC(\fms);

	BP(\swells).free;
	PR(\swellTrig).chuck(BP(\swells), nil, (model: BP(\ml)));
	VC(\fms) => BP(\swells);
	VC(\fms) => MCG(0);
};


BP(\swells).length = Pfunc({ |ev| ~model.points[ev[\i]].mag.last.linlin(~magThresh, 300000, 5.5, 0.6) });

BP(\swells).magThresh = 40000;

BP(\swells).chords = BP(\swells).chords.flop;