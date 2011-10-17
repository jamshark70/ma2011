
// crap. doesn't work b/c 'nexttime' is already decided in the Spawner
// can't move 'nexttime' earlier...

p = Pspawner({ |sp|
	x = sp;
	loop { sp.now.debug("time"); sp.wait(1) };
}).play(quant: 1);

q = p.stream;

x.par(Pn((play: { x.now.debug("\tevent") }), 1), 0.5);
p.stop;
p = EventStreamPlayer(q, Event.default).play(quant: [1, 0.5]);

p.stop;


// don't pull them into the spawner:
// run them separately and track their endings

(
PR(\abstractProcess).clone({

	~prep = {
		~players = IdentityDictionary.new;
	};

	~addStream = { |pattern, quant|
		var	esp = pattern.play(~clock, ~event, quant);
		~players.put(
			esp,
			SimpleController(esp).put(\stopped, e {
				~players.at(esp).remove;  // dump the dependant
				~players.removeAt(esp);
				~players.size.debug("got stopped notification, remaining");
			});
		);
	};
	
	~stopCleanup = {
		// note, can't use keysDo
		// the point of using keys.do is to iterate over a collection
		// that is independent of the collection from which items will be removed
		// have to do this now: if the SimpleController fires after 'free', kaboom
		~players.keys.do { |esp|
			~players.at(esp).remove;
			~players.removeAt(esp);
			esp.stop;
		};
	};

	~asPattern = {
		Pn(Event.silent(1), inf)  // need a dummy to keep BP alive
	};
}) => PR(\spawnerResched);
)

BP(\sr).free;
PR(\spawnerResched) => BP(\sr);

BP(\sr).play;
BP(\sr).isPlaying;

BP(\sr).addStream(Pbind(
	\degree, Pwhite(-7, 7, inf),
	\dur, 0.25
));

BP(\sr).addStream(Pbind(
	\degree, Pseries(7, 1, 8),
	\dur, 0.25
));

BP(\sr).stop(0);
