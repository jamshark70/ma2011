
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



(
PR(\abstractProcess).clone({

	~asPattern = {
		Pspawner({ |sp|
			sp.wait(1);
		})
	};
}) => PR(\spawnerResched);
)
