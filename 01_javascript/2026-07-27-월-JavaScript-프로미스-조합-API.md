# JavaScript 프로미스 (Promise) — 4일차: 조합 API(all·allSettled·race·any)·에러 전파

## 잘 알고 있는지

- 🤔

## 내가 아는 만큼 설명

-

## 답을 본 뒤 알게 된 것

## A. Promise.all

- 프로미스들이 담긴 이터러블(보통 배열)을 받아서, 새 프로미스 하나를 반환하는 정적 메서드.
  - 정적 메서드(static method): Promise.prototype이 아니라 Promise 생성자 자체에 붙어 있는 메서드. 그래서 p.all()이 아니라 Promise.all()로 부른다.
  - settle: fulfilled 또는 rejected로 확정되는 것. pending이 아닌 상태가 되는 것 전부를 가리키는 말.

### 반환 프로미스가 settle되는 규칙

```js
const p = Promise.all([p1, p2, p3]);
```

- 전부 fulfilled -> p가 fulfilled. 값은 각 프로미스의 결과를 인자로 넘긴 순서대로 담은 배열.
- 하나라도 rejected -> 그 즉시 p가 rejected. 이유는 첫 번째로 reject된 것의 이유 하나. 나머지는 안 기다린다.

```js
const p1 = Promise.resolve(1);
const p2 = new Promise((r) => setTimeout(() => r(2), 100));
const p3 = Promise.resolve(3);

Promise.all([p1, p2, p3]).then((v) => console.log(v));
// [1, 2, 3]
```

- 여기서 p2가 가장 늦게 끝나지만 결과 배열은 [1, 2, 3]이야. 완료 순서가 아니라 인자 순서로 담긴다.

```js
const p1 = new Promise((_, rej) => setTimeout(() => rej("A"), 200));
const p2 = new Promise((_, rej) => setTimeout(() => rej("B"), 100));

Promise.all([p1, p2])
  .then((v) => console.log("then:", v))
  .catch((e) => console.log("catch:", e));
```

- Q. 무엇이 출력되고, 몇 ms에 나오는가?
- A. catch: B, 100ms 시점

- Q. 그러면 p1은 어떻게 되는가?
- A. 200ms에 rej("A")는 실행되지만 Promise.all 쪽에서 무시됨.

```js
// Promise.all의 동작을 단순화한 형태
function all(promises) {
  return new Promise((resolve, reject) => {
    const results = [];
    let count = 0;

    promises.forEach((p, i) => {
      p.then(
        (v) => {
          results[i] = v; // ← 인자 순서 유지되는 이유
          count++;
          if (count === promises.length) resolve(results);
        },
        (e) => reject(e), // ← 먼저 도달한 놈이 확정시킴
      );
    });
  });
}
```

```js
Promise.all([1, Promise.resolve(2), "hello"]).then((v) => console.log(v));
```

- Q. 프로미스가 아닌 값이 섞여 있다. 출력이 어떻게 될까? 그리고 이 코드는 몇 개의 프로미스를 기다리는 셈일까?
- A. 프로미스가 아닌 값은 Promise.resolve()로 감싸진다. Promise.all은 원소가 프로미스인지 검사해서 골라내지 않고, 전부 프로미스로 만들어서 똑같이 취급한다.

```js
Promise.all([1, Promise.resolve(2), "hello"]).then((v) => console.log(v));

// 내부적으로 이렇게 취급됨
Promise.all([
  Promise.resolve(1), // 이미 fulfilled, 값 1
  Promise.resolve(2), // 원래 프로미스, 그대로
  Promise.resolve("hello"), // 이미 fulfilled, 값 "hello"
]);
```

- A. 그리고 출력은 [1, 2, "hello"].

## B. Promise.allSettled

- Promise.allSettled(iterable) — all과 같은 형태로 이터러블을 받아 새 프로미스 하나를 반환하는 정적 메서드.
- 이름 그대로 전부 settle될 때까지 기다린다. settle은 A에서 정의한 대로 fulfilled 또는 rejected로 확정되는 것. 즉 성공이든 실패든 상관없이 pending이 아니게 되기만 하면 돼.

- settle 규칙

```js
const p = Promise.allSettled([p1, p2, p3]);
```

- 전부 settle되면 -> p가 fulfilled.
- reject 조건이 없다. allSettled가 반환한 프로미스는 어떤 경우에도 rejected되지 않는다. 원소가 전부 reject돼도 반환 프로미스는 fulfilled. 그래서 오히려 `all`과 시간 차이가 생기는데...

```js
const p1 = new Promise((_, rej) => setTimeout(() => rej("A"), 200));
const p2 = new Promise((_, rej) => setTimeout(() => rej("B"), 100));

Promise.all([p1, p2]).catch((e) => console.log("all:", e));
// 100ms에 확정. 첫 reject 시점

Promise.allSettled([p1, p2]).then((v) => console.log("allSettled:", v));
// 200ms에 확정. 전부 settle될 때까지 기다림
```

- 반환값의 형태
- 여기가 all과 가장 크게 다른 지점. 값이 그대로 담기는 게 아니라 객체로 감싸져서 담김.

```
{ status: "fulfilled", value: 결과값 }
{ status: "rejected", reason: 실패이유 }
```

```js
Promise.allSettled([Promise.resolve(1), Promise.reject("err")]).then((v) =>
  console.log(v),
);

// [
//   { status: "fulfilled", value: 1 },
//   { status: "rejected", reason: "err" }
// ]
```

- 배열 순서는 all과 같이 인자 순서.

```js
const p1 = new Promise((r) => setTimeout(() => r("성공"), 100));
const p2 = Promise.reject("실패");

Promise.allSettled([p1, p2])
  .then((v) => console.log("then:", v))
  .catch((e) => console.log("catch:", e));
```

- Q. then, catch중 어떤게 실행될까?
- A. then

- Q. 출력되는 값을 정확한 형태로.
- A.

```js
then: [
  { status: "fulfilled", value: "성공" },
  { status: "rejected", reason: "실패" },
];
```

- Q. 출력되는 타이밍(ms)는?
- A. 100ms

- 정리하면, allSettled가 반환한 프로미스는 어떤 경우에도 rejected되지 않는다. 원소가 전부 reject돼도 반환 프로미스는 fulfilled.

## C. Promise.race vs Promise.any

- 둘 다 이터러블을 받아 새 프로미스 하나를 반환하는 정적 메서드. 공통점은 전부 기다리지 않고 가장 먼저 하나가 나오면 확정된다는 것.

- race: 가장 먼저 settle된 것. 성공이든 실패든 상관없음.
- any: 가장 먼저 fulfilled된 것. 실패는 세지 않음.

### race

```js
const p1 = new Promise((r) => setTimeout(() => r("A"), 100));
const p2 = new Promise((_, rej) => setTimeout(() => rej("B"), 50));

Promise.race([p1, p2])
  .then((v) => console.log("then:", v))
  .catch((e) => console.log("catch:", e));

// 50ms: catch: B
```

- p2가 먼저 끝났고 그게 실패니까 반환 프로미스도 실패. race는 승자를 가릴 뿐 성공을 찾아주지 않는다.

### any

```js
// 위와 같은 p1, p2
Promise.any([p1, p2])
  .then((v) => console.log("then:", v))
  .catch((e) => console.log("catch:", e));

// 100ms: then: A
```

- fulfilled된 것만 승자로 인정한다. reject는 무시하고 계속 기다려.
- 50ms에 p2가 실패했지만 무시하고 계속 기다렸다가, 100ms에 p1이 성공하자 그 값으로 확정.

```js
Promise.any([Promise.reject("A"), Promise.reject("B")]).catch((e) => {
  console.log(e.name); // "AggregateError"
  console.log(e.errors); // ["A", "B"]
});
```

- 그럼 any는 언제 실패하냐 — 전부 rejected일 때만. 이때 reject 이유가 특이하다.
- AggregateError는 여러 에러를 하나로 묶어서 담는 에러 타입이야. errors 속성에 각 실패 이유가 인자 순서대로 배열로 들어있다.
- A에서 "reject 이유는 값 하나뿐이라 여러 개를 담을 자리가 없다"고 했는데, any는 그 제약을 이렇게 우회한 것임.
- 값 하나이긴 한데 그 하나가 배열을 품은 에러 객체.

```js
Promise.all([]); // 즉시 fulfilled, 값 []
Promise.allSettled([]); // 즉시 fulfilled, 값 []
Promise.race([]); // 영원히 pending  ← 승자가 나올 수 없음
Promise.any([]); // 즉시 rejected, AggregateError
```

- 빈 배열을 넣으면 넷 다 동작이 달라서 정리해두면 좋아.

```js
const p1 = new Promise((_, rej) => setTimeout(() => rej("X"), 50));
const p2 = new Promise((r) => setTimeout(() => r("Y"), 150));
const p3 = new Promise((_, rej) => setTimeout(() => rej("Z"), 100));

Promise.race([p1, p2, p3])
  .then((v) => console.log("race then:", v))
  .catch((e) => console.log("race catch:", e));
Promise.any([p1, p2, p3])
  .then((v) => console.log("any then:", v))
  .catch((e) => console.log("any catch:", e));
```

- Q. 출력되는 두 줄과 시점을 쓰시오
- A.

```
race catch: X, 50ms
any then: Y, 150ms
```

## D. 에러 전파

- 에러 전파(error propagation)
  — 프로미스 체인의 어느 지점에서 발생한 rejection이, 뒤에 이어진 핸들러들을 어떤 순서로 통과해 어디까지 흘러가는가.

- 먼저 1일차에서 확인한 것 하나를 다시 꺼내야 함.
- then은 항상 새 프로미스를 반환.
- 체인이란 건 프로미스가 한 줄로 이어진 구조고, 에러 전파는 그 줄을 따라 rejected 상태가 옮겨가는 과정.

```js
p.then(onFulfilled, onRejected);
```

- then은 2가지 인자를 받는다.
- catch(fn)은 별개의 메서드가 아니라 then(undefined, fn)의 축약이었음.

### catch 이후에는 fulfilled로 돌아온다

```js
Promise.reject("err")
  .catch((e) => console.log("catch:", e))
  .then(() => console.log("then 실행됨"));

// catch: err
// then 실행됨
```

- catch도 then이니까 새 프로미스를 반환한다.
- 그리고 핸들러가 정상적으로 끝났으면(throw 안 하고) 그 반환 프로미스는 fulfilled.
- 에러를 처리했으니 체인이 정상 상태로 복귀한 것.
- 값은 핸들러의 반환값. 위 코드의 console.log는 undefined를 반환하니까 fulfilled 값은 undefined.
- 에러를 다시 흘려보내려면 명시적으로 throw해야 함.

```js
Promise.reject("err")
  .catch((e) => {
    throw e;
  })
  .then(() => console.log("실행 안 됨"))
  .catch((e) => console.log("두번째 catch:", e));

// 두번째 catch: err
```

```js
Promise.resolve(1)
  .catch((e) => console.log("A:", e))
  .then(() => {
    throw "여기서 에러";
  })
  .then(() => console.log("실행 안 됨"));

// 아무것도 안 찍힘 + unhandled rejection 경고
```

- catch 위치
- 체인 중간에 두면 그 뒤에서 난 에러는 못 잡음.

```js
Promise.resolve("시작")
  .then((v) => {
    throw "터짐";
  })
  .then((v) => console.log("A:", v))
  .catch((e) => {
    console.log("B:", e);
    return "복구";
  })
  .then((v) => console.log("C:", v))
  .catch((e) => console.log("D:", e));
```

- Q. 출력 결과 쓰시오
- A.

```
A: 터짐
B: 터짐
C: 복구
```

- catch(fn) = then(undefined, fn). 별개 메서드가 아니라 축약형.
- rejected면 onFulfilled는 실행 자체가 안 됨. 인자로 에러가 들어오는 게 아니라 건너뜀. rejected 핸들러를 만날 때까지 아래로 흐름.
- 핸들러 안의 throw → 그 then의 반환 프로미스가 rejected.
- catch 핸들러가 정상 종료되면 반환 프로미스는 fulfilled. 체인이 정상 복귀하고 뒤 then이 돎. 값은 핸들러 반환값.
- 에러를 계속 흘리려면 catch 안에서 다시 throw.
- catch는 자기 위쪽 rejection만 잡음. 그래서 체인 끝에 둠.

## E. finally

- p.finally(onFinally)
  — 프로미스가 settle되면 성공·실패 상관없이 실행되는 핸들러를 등록하는 메서드. then, catch와 같이 Promise.prototype에 있는 인스턴스 메서드고, 새 프로미스를 반환하는 것도 같다.

- then, catch와 다른 점이 두 가지.

1. 핸들러가 인자를 안 받음.

```js
p.finally(() => { ... })   // 인자 없음
```

- 성공했는지 실패했는지 구분하지 않는 자리라서, value도 reason도 전달되지 않음.
- 상태를 알아야 하는 로직은 애초에 finally에 넣을 게 아니라는 뜻.
- 로딩 스피너 끄기, 연결 닫기처럼 결과와 무관하게 해야 하는 정리 작업이 들어가는 자리.

2. 값을 통과시킨다.

```js
Promise.resolve("원래값")
  .finally(() => "무시됨")
  .then((v) => console.log(v));

// 원래값

Promise.reject("에러")
  .finally(() => console.log("정리"))
  .catch((e) => console.log("catch:", e));

// 정리
// catch: 에러
```

- finally를 통과해도 rejected 상태가 유지되니까 뒤의 catch가 정상적으로 잡음.

### 얘외: throw하면 반영된다

```js
Promise.resolve("원래값")
  .finally(() => {
    throw "정리중 에러";
  })
  .then((v) => console.log("then:", v))
  .catch((e) => console.log("catch:", e));

// catch: 정리중 에러
```

- finally 안에서 throw하면 원래 fulfilled였던 게 rejected로 덮여. 원래 값 "원래값"은 사라져.

```js
Promise.reject("A")
  .finally(() => "B")
  .catch((e) => {
    console.log("1:", e);
    return "C";
  })
  .finally(() => {
    console.log("2");
  })
  .then((v) => console.log("3:", v));
```

- Q. 출력값을 쓰시오
- A.

```
1:A
2
3:C
```

## 틀렸거나 부족했던 부분

- 생략

## 면접용 1분 답변

```
프로미스 조합 API는 여러 프로미스를 하나로 묶는 정적 메서드 네 개입니다. 넷 다 프로미스가 아닌 값은 Promise.resolve로 감싸서 동일하게 취급하고, 새 프로미스 하나를 반환합니다. 차이는 언제 확정되느냐입니다.

all은 전부 fulfilled여야 성공하고, 하나라도 reject되면 그 즉시 실패합니다.

성공 시 값은 완료 순서가 아니라 인자 순서대로 담긴 배열이고, 실패 시 이유는 시간상 첫 번째 reject의 이유 하나입니다. 이때 나머지 프로미스는 취소되지 않고 계속 실행되다가 무시됩니다. 프로미스에는 취소 개념이 없어서, 네트워크 요청을 실제로 중단하려면 AbortController가 따로 필요합니다.

allSettled는 전부 settle될 때까지 기다리고, 어떤 경우에도 reject되지 않습니다.

결과는 status와 value 또는 reason을 가진 객체 배열로 오기 때문에, 실패를 상태로 전파하는 대신 데이터로 받아서 직접 분기하게 됩니다. 하나가 실패해도 나머지 성공 결과를 살려야 할 때 all 대신 씁니다.

race와 any는 둘 다 가장 먼저 나온 하나로 확정되는데 기준이 다릅니다. race는 첫 settle이라 성공·실패를 가리지 않고, any는 첫 fulfilled라 실패는 무시하고 계속 기다립니다. any는 전부 실패할 때만 reject되며 이유는 AggregateError이고, errors 속성에 모든 실패 이유가 배열로 들어갑니다.

에러 전파는 then이 항상 새 프로미스를 반환한다는 데서 나옵니다. catch는 then(undefined, fn)의 축약이고, 앞이 rejected면 onFulfilled는 인자를 받는 게 아니라 실행 자체가 건너뛰어집니다. catch 핸들러가 정상 종료되면 반환 프로미스는 fulfilled가 되어 체인이 정상 복귀하므로, 에러를 계속 흘리려면 안에서 다시 throw해야 합니다. catch는 자기 위쪽 rejection만 잡아서 보통 체인 끝에 둡니다. finally는 인자를 받지 않고 반환값도 무시되며 원래 상태와 값을 그대로 통과시키는데, throw만은 예외로 반영되어 원래 값을 덮습니다.
```

## 한 줄 요약

- 넷 다 정적 메서드. 프로미스 아닌 값은 `Promise.resolve()`로 감싸서 동일 취급하고, 새 프로미스 하나를 반환한다.
- `all`: 전부 fulfilled면 성공, 하나라도 reject면 즉시 실패.
- `all` 성공값은 완료 순서가 아니라 **인자 순서** 배열. 실패 이유는 시간상 첫 reject의 이유 **하나**.
- 프로미스에 취소는 없다. `all`이 실패해도 나머지는 계속 실행되고 무시된다. 요청 중단은 `AbortController`.
- `allSettled`: 전부 settle까지 대기. **절대 reject되지 않는다.**
- `allSettled` 결과는 `{status:"fulfilled", value}` / `{status:"rejected", reason}` 객체 배열. 실패를 상태가 아닌 **데이터**로 받는다.
- `race`: 첫 **settle**. 성공·실패 안 가림.
- `any`: 첫 **fulfilled**. 실패는 무시하고 계속 기다림.
- `any`는 전부 실패할 때만 reject. 이유는 `AggregateError`, `.errors`에 전부 인자 순서로 담김.
- 빈 배열: `all`/`allSettled`는 즉시 fulfilled `[]`, `race`는 **영원히 pending**, `any`는 즉시 `AggregateError`.
- `catch(fn)`은 `then(undefined, fn)`의 축약.
- rejected면 `onFulfilled`는 **실행 자체가 안 된다.** 에러가 인자로 들어오는 게 아니라 건너뛴다.
- 핸들러 안의 `throw` → 그 `then`의 반환 프로미스가 rejected.
- `catch` 핸들러가 정상 종료되면 반환 프로미스는 **fulfilled**. 뒤 `then`이 돈다. 계속 흘리려면 다시 `throw`.
- `catch`는 자기 **위쪽** rejection만 잡는다. 그래서 체인 끝에 둔다.
- `finally`: 인자 없음, 반환값 무시, 원래 상태·값 그대로 통과. rejected도 통과시켜 뒤 `catch`가 잡는다.
- `finally` 안의 `throw`는 예외적으로 반영되어 원래 값을 덮는다.

"promise는 어떤 작업의 성공 혹은 실패 같은 상태와 그 작업의 결과를 나타내는 객체"
