# Changelog

## [0.1.1](https://github.com/nmbrone/rkv/compare/v0.1.0...v0.1.1) (2026-09-02)


### Bug Fixes

* distinguish a stored nil from a missing key in fetch/2 ([#20](https://github.com/nmbrone/rkv/issues/20)) ([2f58948](https://github.com/nmbrone/rkv/commit/2f5894880e1521503b0a7e2794d8cd227b4ef9c7))
* do not notify watchers when deleting an absent key ([#21](https://github.com/nmbrone/rkv/issues/21)) ([c2302b3](https://github.com/nmbrone/rkv/commit/c2302b3504292ee1f2175fffde1d6727fab0c696))
* raise ArgumentError instead of RuntimeError ([#23](https://github.com/nmbrone/rkv/issues/23)) ([d1bc419](https://github.com/nmbrone/rkv/commit/d1bc41964ce269dd83f86fa585d45a792f5c9fbc))

## 0.1.0 (2026-02-18)


### Miscellaneous Chores

* initial release ([071106a](https://github.com/nmbrone/rkv/commit/071106a60fb1de79132fc05fcdc12da8e8b38f63))
