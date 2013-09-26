library di.tests;

import 'fixed-unittest.dart';
import 'package:di/di.dart';
import 'package:di/dynamic_injector.dart' hide ObjectFactory;
import 'package:di/static_injector.dart';

// just some classes for testing
class Engine {
  String id = 'v8-id';
}

class MockEngine implements Engine {
  String id = 'mock-id';
}

class MockEngine2 implements Engine {
  String id = 'mock-id-2';
}

class Car {
  Engine engine;
  Injector injector;

  Car(Engine this.engine, Injector this.injector);
}

class NumDependency {
  NumDependency(num value) {}
}

class IntDependency {
  IntDependency(int value) {}
}

class DoubleDependency {
  DoubleDependency(double value) {}
}

class StringDependency {
  StringDependency(String value) {}
}

class BoolDependency {
  BoolDependency(bool value) {}
}


class CircularA {
  CircularA(CircularB b) {}
}

class CircularB {
  CircularB(CircularA a) {}
}

typedef int CompareInt(int a, int b);

int compareIntAsc(int a, int b) {
  if (a == b) {
    return 0;
  }
  if (a < b) {
    return 1;
  }
  return -1;
}

class WithTypeDefDependency {
  CompareInt compare;

  WithTypeDefDependency(CompareInt c) {
    compare = c;
  }
}

class MultipleConstructors {
  String instantiatedVia;
  MultipleConstructors() : instantiatedVia = 'default';
  MultipleConstructors.named() : instantiatedVia = 'named';
}

void main() {
  testModule();

  createInjectorSpec('DynamicInjector',
      (modules, [name]) => new DynamicInjector(modules: modules, name: name));

  Map<Type, TypeFactory> typeFactories = new Map<Type, TypeFactory>();
  typeFactories[Engine] = (ObjectFactory factory) {
    return new Engine();
  };
  typeFactories[MockEngine] = (ObjectFactory factory) {
    return new MockEngine();
  };
  typeFactories[MockEngine2] = (ObjectFactory factory) {
    return new MockEngine2();
  };
  typeFactories[Car] = (ObjectFactory factory) {
    return new Car(factory(Engine), factory(Injector));
  };
  typeFactories[NumDependency] = (ObjectFactory factory) {
    return new NumDependency(factory(num));
  };
  typeFactories[IntDependency] = (ObjectFactory factory) {
    return new IntDependency(factory(int));
  };
  typeFactories[DoubleDependency] = (ObjectFactory factory) {
    return new DoubleDependency(factory(double));
  };
  typeFactories[StringDependency] = (ObjectFactory factory) {
    return new StringDependency(factory(String));
  };
  typeFactories[BoolDependency] = (ObjectFactory factory) {
    return new BoolDependency(factory(bool));
  };
  typeFactories[CircularA] = (ObjectFactory factory) {
    return new CircularA(factory(CircularB));
  };
  typeFactories[CircularB] = (ObjectFactory factory) {
    return new CircularB(factory(CircularA));
  };
  typeFactories[MultipleConstructors] = (ObjectFactory factory) {
    return new MultipleConstructors();
  };
  createInjectorSpec('StaticInjector',
      (modules, [name]) => new StaticInjector(modules: modules, name: name,
          typeFactories: typeFactories));
}

testModule() => describe('Module', () {

  it('should do basic type binding', () {
    var module = new Module()
      ..type(Engine);

    var binding = module.bindings[Engine];
    expect(binding, isNotNull);
    expect(binding, new isInstanceOf<TypeBinding>());
    expect(binding.type, Engine);
  });


  it('should do type implementedBy binding', () {
    var module = new Module()
      ..type(Engine, implementedBy: MockEngine);

    var binding = module.bindings[Engine];
    expect(binding, isNotNull);
    expect(binding, new isInstanceOf<TypeBinding>());
    expect(binding.type, MockEngine);
  });


  it('should do value binding', () {
    var engine = new MockEngine();
    var module = new Module()
      ..value(Engine, engine);

    var binding = module.bindings[Engine];
    expect(binding, isNotNull);
    expect(binding, new isInstanceOf<ValueBinding>());
    expect(binding.value, same(engine));
  });


  it('should do factory binding', () {
    var factory = (Injector i) => new MockEngine();
    var module = new Module()
      ..factory(Engine, factory);

    var binding = module.bindings[Engine];
    expect(binding, isNotNull);
    expect(binding, new isInstanceOf<FactoryBinding>());
    expect(binding.factoryFn, same(factory));
  });


  it('should install modules', () {
    var parentModule = new Module()
      ..type(Engine);

    var childModule = new Module()
      ..type(Car);

    expect(parentModule.bindings.keys, [Engine]);
    parentModule.install(childModule);
    expect(parentModule.bindings.keys, unorderedEquals([Car, Engine]));
  });


  it('should use parent binding instead of child', () {
    var parentModule = new Module()
      ..type(Car)
      ..type(Engine, implementedBy: MockEngine);

    var childModule = new Module()
      ..type(Engine, implementedBy: MockEngine2);

    var parentBinding = parentModule.bindings[Engine];
    expect(parentBinding, isNotNull);
    expect(parentBinding, new isInstanceOf<TypeBinding>());
    expect(parentBinding.type, MockEngine);

    parentModule.install(childModule);

    parentBinding = parentModule.bindings[Engine];
    expect(parentBinding, isNotNull);
    expect(parentBinding, new isInstanceOf<TypeBinding>());
    expect(parentBinding.type, MockEngine);
  });
});

typedef Injector InjectorFactory(List<Module> modules, [String name]);

createInjectorSpec(String injectorName, InjectorFactory injectorFactory) {

  describe(injectorName, () {

    it('should instantiate a type', () {
      var injector = injectorFactory([new Module()..type(Engine)]);
      var instance = injector.get(Engine);

      expect(instance, instanceOf(Engine));
      expect(instance.id, toEqual('v8-id'));
    });

    it('should fail if no binding is found', () {
      var injector = injectorFactory([]);
      expect(() {
        injector.get(Engine);
      }, toThrow(NoProviderError, 'No provider found for Engine! '
      '(resolving Engine)'));
    });


    it('should resolve basic dependencies', () {
      var injector = injectorFactory([new Module()..type(Car)..type(Engine)]);
      var instance = injector.get(Car);

      expect(instance, instanceOf(Car));
      expect(instance.engine.id, toEqual('v8-id'));
    });


    it('should allow modules and overriding providers', () {
      var module = new Module();
      module.type(Engine, implementedBy: MockEngine);

      // injector is immutable
      // you can't load more modules once it's instantiated
      // (you can create a child injector)
      var injector = injectorFactory([module]);
      var instance = injector.get(Engine);

      expect(instance.id, toEqual('mock-id'));
    });


    it('should only create a single instance', () {
      var injector = injectorFactory([new Module()..type(Engine)]);
      var first = injector.get(Engine);
      var second = injector.get(Engine);

      expect(first, toBe(second));
    });


    it('should allow providing values', () {
      var module = new Module();
      module.value(Engine, 'str value');
      module.value(Car, 123);

      var injector = injectorFactory([module]);
      var abcInstance = injector.get(Engine);
      var complexInstance = injector.get(Car);

      expect(abcInstance, toEqual('str value'));
      expect(complexInstance, toEqual(123));
    });


    it('should allow providing factory functions', () {
      var module = new Module();
      module.factory(Engine, (Injector injector) {
        return 'factory-product';
      });

      var injector = injectorFactory([module]);
      var instance = injector.get(Engine);

      expect(instance, toEqual('factory-product'));
    });


    it('should inject injector into factory function', () {
      var module = new Module();
      module.type(Engine);
      module.factory(Car, (Injector injector) {
        return new Car(injector.get(Engine), injector);
      });

      var injector = injectorFactory([module]);
      var instance = injector.get(Car);

      expect(instance, instanceOf(Car));
      expect(instance.engine.id, toEqual('v8-id'));
    });


    it('should throw an exception when injecting a primitive type', () {
      var injector = injectorFactory([
        new Module()
          ..type(NumDependency)
          ..type(IntDependency)
          ..type(DoubleDependency)
          ..type(BoolDependency)
          ..type(StringDependency)
      ]);

      expect(() {
        injector.get(NumDependency);
      }, toThrow(NoProviderError, 'Cannot inject a primitive type of num! '
      '(resolving NumDependency -> num)'));

      expect(() {
        injector.get(IntDependency);
      }, toThrow(NoProviderError, 'Cannot inject a primitive type of int! '
      '(resolving IntDependency -> int)'));

      expect(() {
        injector.get(DoubleDependency);
      }, toThrow(NoProviderError, 'Cannot inject a primitive type of double! '
      '(resolving DoubleDependency -> double)'));

      expect(() {
        injector.get(BoolDependency);
      }, toThrow(NoProviderError, 'Cannot inject a primitive type of bool! '
      '(resolving BoolDependency -> bool)'));

      expect(() {
        injector.get(StringDependency);
      }, toThrow(NoProviderError, 'Cannot inject a primitive type of String! '
      '(resolving StringDependency -> String)'));
    });


    it('should throw an exception when circular dependency', () {
      var injector = injectorFactory([new Module()..type(CircularA)..type(CircularB)]);

      expect(() {
        injector.get(CircularA);
      }, toThrow(CircularDependencyError, 'Cannot resolve a circular dependency! '
          '(resolving CircularA -> '
      'CircularB -> CircularA)'));
    });


    it('should provide the injector as Injector', () {
      var injector = injectorFactory([]);

      expect(injector.get(Injector), toBe(injector));
    });


    // Typedef injection is not supported in dart2js: http://dartbug.com/11612
    xit('should inject a typedef', () {
      var module = new Module();
      module.value(CompareInt, compareIntAsc);

      var injector = injectorFactory([module]);
      var compare = injector.get(CompareInt);

      expect(compare(1, 2), toBe(1));
      expect(compare(5, 2), toBe(-1));
    });


    // Typedef injection is not supported in dart2js: http://dartbug.com/11612
    xit('should throw an exception when injecting typedef without providing it', () {
      var injector = injectorFactory([new Module()..type(WithTypeDefDependency)]);

      expect(() {
        injector.get(WithTypeDefDependency);
      }, toThrow(NoProviderError, 'No provider found for CompareInt! '
      '(resolving WithTypeDefDependency -> CompareInt)'));
    });


    it('should instantiate via the default/unnamed constructor', () {
      var injector = injectorFactory([new Module()..type(MultipleConstructors)]);
      MultipleConstructors instance = injector.get(MultipleConstructors);
      expect(instance.instantiatedVia, 'default');
    });

    // CHILD INJECTORS
    it('should inject from child', () {
      var module = new Module();
      module.type(Engine, implementedBy: MockEngine);

      var parent = injectorFactory([new Module()..type(Engine)]);
      var child = parent.createChild([module]);

      var abcFromParent = parent.get(Engine);
      var abcFromChild = child.get(Engine);

      expect(abcFromParent.id, toEqual('v8-id'));
      expect(abcFromChild.id, toEqual('mock-id'));
    });


    it('should enumerate across children', () {
      var parent = injectorFactory([new Module()..type(Engine)]);
      var child = parent.createChild([new Module()..type(MockEngine)]);

      expect(parent.types, unorderedEquals(new Set.from([Engine, Injector])));
      expect(child.types, unorderedEquals(new Set.from([Engine, MockEngine, Injector])));
    });


    it('should inject instance from parent if not provided in child', () {
      var module = new Module();
      module.type(Car);

      var parent = injectorFactory([new Module()..type(Car)..type(Engine)]);
      var child = parent.createChild([module]);

      var complexFromParent = parent.get(Car);
      var complexFromChild = child.get(Car);
      var abcFromParent = parent.get(Engine);
      var abcFromChild = child.get(Engine);

      expect(complexFromChild, not(toBe(complexFromParent)));
      expect(abcFromChild, toBe(abcFromParent));
    });


    it('should inject instance from parent but never use dependency from child', () {
      var module = new Module();
      module.type(Engine, implementedBy: MockEngine);

      var parent = injectorFactory([new Module()..type(Car)..type(Engine)]);
      var child = parent.createChild([module]);

      var complexFromParent = parent.get(Car);
      var complexFromChild = child.get(Car);
      var abcFromParent = parent.get(Engine);
      var abcFromChild = child.get(Engine);

      expect(complexFromChild, toBe(complexFromParent));
      expect(complexFromChild.engine, toBe(abcFromParent));
      expect(complexFromChild.engine, not(toBe(abcFromChild)));
    });


    it('should force new instance in child even if already instantiated in parent', () {
      var parent = injectorFactory([new Module()..type(Engine)]);
      var abcAlreadyInParent = parent.get(Engine);

      var child = parent.createChild([], forceNewInstances: [Engine]);
      var abcFromChild = child.get(Engine);

      expect(abcFromChild, not(toBe(abcAlreadyInParent)));
    });


    it('should force new instance in child using provider from grand parent', () {
      var module = new Module();
      module.type(Engine, implementedBy: MockEngine);

      var grandParent = injectorFactory([module]);
      var parent = grandParent.createChild([]);
      var child = parent.createChild([], forceNewInstances: [Engine]);

      var abcFromGrandParent = grandParent.get(Engine);
      var abcFromChild = child.get(Engine);

      expect(abcFromChild.id, toEqual(('mock-id')));
      expect(abcFromChild, not(toBe(abcFromGrandParent)));
    });


    it('should provide child injector as Injector', () {
      var injector = injectorFactory([]);
      var child = injector.createChild([]);

      expect(child.get(Injector), toBe(child));
    });


    it('should set the injector name', () {
      var injector = injectorFactory([], 'foo');
      expect(injector.name, 'foo');
    });


    it('should set the child injector name', () {
      var injector = injectorFactory([], 'foo');
      var childInjector = injector.createChild(null, name: 'bar');
      expect(childInjector.name, 'bar');
    });


    describe('creation strategy', () {

      it('should get called for instance creation', () {

        List creationLog = [];
        dynamic creation(Injector requesting, Injector defining, factory) {
          creationLog.add([requesting, defining]);
          return factory();
        }

        var parentModule = new Module()
          ..type(Engine, implementedBy: MockEngine, creation: creation)
          ..type(Car, creation: creation);

        var parentInjector = injectorFactory([parentModule]);
        var childInjector = parentInjector.createChild([]);
        childInjector.get(Car);
        expect(creationLog, [
          [childInjector, parentInjector],
          [childInjector, parentInjector]
        ]);
      });

      it('should be able to prevent instantiation', () {

        List creationLog = [];
        dynamic creation(Injector requesting, Injector defining, factory) {
          throw 'not allowing';
        }

        var module = new Module()
          ..type(Engine, implementedBy: MockEngine, creation: creation);
        var injector = injectorFactory([module]);
        expect(() {
          injector.get(Engine);
        }, throwsA('not allowing'));
      });
    });


    describe('visiblity', () {

      it('should hide instances', () {

        var rootMock = new MockEngine();
        var childMock = new MockEngine();

        var parentModule = new Module()
          ..value(Engine, rootMock);
        var childModule = new Module()
          ..value(Engine, childMock, visibility: (_, __) => false);

        var parentInjector = injectorFactory([parentModule]);
        var childInjector = parentInjector.createChild([childModule]);

        var val = childInjector.get(Engine);
        expect(val, same(rootMock));
      });

    });

  });

}
