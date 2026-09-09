:- encoding(utf8).
:- module(hotel_frames,
          [frame/2, instance/1, parent/2, slot/3, get_slot/4,
           describe/2, consult_tariff/3, demo/0]).
:- use_module(library(lists)).

% Вариант 2: фреймы. Учебная модель, работающая локально.
% Два уровня: общий фрейм-прототип и два конкретных объекта.
frame(tariff, prototype).
frame(standard_rate, instance).
frame(promo_rate, instance).
instance(Object) :- frame(Object, instance).

parent(standard_rate, tariff).
parent(promo_rate, tariff).

% Значения по умолчанию общего фрейма.
slot(tariff, currency, rub).
slot(tariff, website_enabled, yes).
slot(tariff, payment_method, on_arrival).
slot(tariff, min_nights, 1).

% Объект 1: пять собственных и четыре наследуемых значения.
slot(standard_rate, name, 'Стандартный тариф').
slot(standard_rate, price, 5000).
slot(standard_rate, active, yes).
slot(standard_rate, rooms_available, yes).
slot(standard_rate, meal, breakfast).

% Объект 2: шесть собственных и три наследуемых значения.
% min_nights переопределяет значение общего фрейма.
slot(promo_rate, name, 'Промотариф').
slot(promo_rate, price, 4000).
slot(promo_rate, active, no).
slot(promo_rate, rooms_available, no).
slot(promo_rate, meal, none).
slot(promo_rate, min_nights, 3).

known_slot(name).
known_slot(price).
known_slot(active).
known_slot(rooms_available).
known_slot(meal).
known_slot(currency).
known_slot(website_enabled).
known_slot(payment_method).
known_slot(min_nights).

require_frame(Frame) :-
    ( atom(Frame), frame(Frame, _) -> true
    ; throw(error(unknown_frame(Frame), get_slot/4)) ).

require_instance(Object) :-
    ( atom(Object), instance(Object) -> true
    ; throw(error(unknown_object(Object), consult_tariff/3)) ).

% get_slot(+Frame, +Slot, ?Value, ?Origin).
% Сначала выбирается ближайшее определение, затем проверяется Value.
% Поэтому запрос переопределенного значения не вернется к прототипу.
get_slot(Frame, Slot, Value, Origin) :-
    require_frame(Frame),
    ( atom(Slot), known_slot(Slot) -> true
    ; throw(error(unknown_slot(Slot), get_slot/4)) ),
    resolve_slot(Frame, Slot, [], ResolvedValue, Owner),
    Value = ResolvedValue,
    ( Frame == Owner -> Origin = own(Frame)
    ; Origin = inherited(Owner) ).

resolve_slot(Frame, Slot, Visited, Value, Owner) :-
    \+ memberchk(Frame, Visited),
    ( slot(Frame, Slot, Local) -> Value = Local, Owner = Frame
    ; parent(Frame, Parent),
      resolve_slot(Parent, Slot, [Frame|Visited], Value, Owner) ).

% Эффективные значения фрейма с указанием происхождения.
describe(Frame, Properties) :-
    require_frame(Frame),
    findall(property(Slot, Value, Origin),
            (known_slot(Slot), get_slot(Frame, Slot, Value, Origin)),
            Properties).

% Продукционные правила над значениями слотов, включая наследуемые.
rule(r01, [eq(active, no)],
     'Тариф неактивен. Проверьте, требуется ли его активация.').
rule(r02, [eq(rooms_available, no)],
     'Нет доступных номеров. Проверьте даты и наличие номеров.').
rule(r03, [eq(website_enabled, no)],
     'Сайт выключен в источниках продаж. Проверьте настройки тарифа.').
rule(r04, [stay_below_minimum],
     'Срок проживания меньше минимального. Уточните даты или условия тарифа.').

required_slot(active).
required_slot(rooms_available).
required_slot(website_enabled).
required_slot(min_nights).

prove(Object, _, eq(Slot, Value), slot_evidence(Slot, Value, Origin)) :-
    get_slot(Object, Slot, Value, Origin).
prove(Object, Nights, stay_below_minimum,
      stay_evidence(Nights, Minimum, Origin)) :-
    get_slot(Object, min_nights, Minimum, Origin), Nights < Minimum.

% consult_tariff(+Object, +Nights, -Report).
% Nights — число ночей одной рассматриваемой попытки бронирования.
consult_tariff(Object, Nights, report(Status, Findings, Missing)) :-
    require_instance(Object),
    ( integer(Nights), Nights > 0 -> true
    ; throw(error(invalid_nights(Nights), consult_tariff/3)) ),
    findall(finding(Id, Message, Evidence),
            (rule(Id, Conditions, Message),
             maplist(prove(Object, Nights), Conditions, Evidence)),
            Findings),
    findall(Slot,
            (required_slot(Slot), \+ get_slot(Object, Slot, _, _)),
            Missing),
    report_status(Findings, Missing, Status).

report_status([_|_], _, blocked).
report_status([], [_|_], insufficient_data).
report_status([], [], no_known_blockers).

demo :-
    forall(instance(Object),
           (format('~nОбъект: ~w~n', [Object]),
            describe(Object, Properties), maplist(print_property, Properties),
            consult_tariff(Object, 2, Report), print_report(Report))).

print_property(property(Slot, Value, Origin)) :-
    format('  ~w = ~w; ~w~n', [Slot, Value, Origin]).
print_report(report(Status, Findings, Missing)) :-
    format('Консультация на 2 ночи: ~w~n', [Status]),
    forall(member(finding(Id, Message, Evidence), Findings),
           format('  ~w: ~w~n  Основание: ~w~n', [Id, Message, Evidence])),
    ( Missing == [] -> true ; format('Неизвестные слоты: ~w~n', [Missing]) ).
