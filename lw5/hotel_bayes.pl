:- encoding(utf8).
:- module(hotel_bayes,
          [probability/3, marginal/2, posterior/4, demo/0,
           variable/1, parents/2, cpt/3, joint/2]).
:- use_module(library(lists)).

% Учебная байесовская сеть. Вероятности заданы автором модели,
% не оценены по статистике реальной платформы. Состояния переменных: yes и no.
% Один случай: попытка бронирования одного тарифа на выбранные даты.

variable(high_demand).
variable(config_error).
variable(rooms_available).
variable(rate_visible).
variable(booking_success).
variable(help_request).

% Переменные перечислены в топологическом порядке.
parents(high_demand, []).
parents(config_error, []).
parents(rooms_available, [high_demand]).
parents(rate_visible, [config_error]).
parents(booking_success, [rooms_available, rate_visible]).
parents(help_request, [booking_success]).

% cpt(Variable, ParentStates, P_yes).
% Порядок ParentStates соответствует parents/2. P_no = 1 - P_yes.
cpt(high_demand, [], 0.30).
cpt(config_error, [], 0.10).
cpt(rooms_available, [yes], 0.40).
cpt(rooms_available, [no], 0.90).
cpt(rate_visible, [yes], 0.20).
cpt(rate_visible, [no], 0.98).
cpt(booking_success, [yes, yes], 0.85).
cpt(booking_success, [yes, no], 0.00).
cpt(booking_success, [no, yes], 0.00).
cpt(booking_success, [no, no], 0.00).
cpt(help_request, [yes], 0.05).
cpt(help_request, [no], 0.60).

state(yes).
state(no).

% Проверка заданного пользователем события или свидетельств.
validate_assignments(Assignments) :-
    ( is_list(Assignments), ground(Assignments) -> true
    ; throw(error(invalid_assignments(Assignments), probability/3)) ),
    maplist(valid_assignment, Assignments),
    findall(Key, member(Key-_, Assignments), Keys),
    sort(Keys, Unique),
    ( same_length(Keys, Unique) -> true
    ; throw(error(duplicate_variables, probability/3)) ).

valid_assignment(Key-Value) :- variable(Key), state(Value), !.
valid_assignment(Assignment) :-
    throw(error(invalid_assignment(Assignment), probability/3)).

% Перебор полных состояний сети: 2^6 = 64 варианта.
world(World) :- findall(V, variable(V), Variables), assign(Variables, World).
assign([], []).
assign([V|Vs], [V-S|Rest]) :- state(S), assign(Vs, Rest).

lookup(World, Variable, State) :- memberchk(Variable-State, World).

local_probability(World, Variable-State, P) :-
    parents(Variable, ParentVariables),
    maplist(lookup(World), ParentVariables, ParentStates),
    cpt(Variable, ParentStates, PYes),
    ( State == yes -> P = PYes ; P is 1.0-PYes ).

% joint(+World, -P): World должен содержать все шесть переменных.
joint(World, P) :-
    validate_assignments(World),
    findall(V, variable(V), Variables),
    ( same_length(World, Variables) -> true
    ; throw(error(incomplete_world, joint/2)) ),
    joint_unchecked(World, P).

joint_unchecked(World, P) :-
    maplist(local_probability(World), World, Factors),
    multiply(Factors, 1.0, P).

multiply([], P, P).
multiply([F|Fs], Acc, P) :- Next is Acc*F, multiply(Fs, Next, P).

matches(World, Assignments) :- maplist(in_world(World), Assignments).
in_world(World, Assignment) :- memberchk(Assignment, World).

% Суммирование вероятностей всех полных состояний,
% совместимых с наблюдаемыми значениями.
event_mass(Assignments, P) :-
    findall(Weight,
            (world(World), matches(World, Assignments),
             joint_unchecked(World, Weight)),
            Weights),
    sum_list(Weights, P).

% probability(+Query, +Evidence, -P) = P(Query | Evidence).
% Query и Evidence — списки Variable-yes/no, означающие конъюнкции.
% Пустой Query — достоверное событие; пустой Evidence — без наблюдений.
probability(Query, Evidence, P) :-
    validate_assignments(Query), validate_assignments(Evidence),
    event_mass(Evidence, Denominator),
    ( Denominator > 0.0 -> true
    ; throw(error(impossible_evidence(Evidence), probability/3)) ),
    append(Query, Evidence, Combined),
    event_mass(Combined, Numerator),
    P is Numerator/Denominator.

marginal(Event, P) :- probability([Event], [], P).
posterior(Variable, State, Evidence, P) :-
    probability([Variable-State], Evidence, P).

demo :-
    marginal(booking_success-yes, P1),
    posterior(booking_success, yes, [high_demand-yes], P2),
    posterior(config_error, yes, [booking_success-no], P3),
    posterior(config_error, yes, [help_request-yes], P4),
    posterior(booking_success, yes, [rooms_available-no], P5),
    format('1. P(booking_success=yes) = ~6f~n', [P1]),
    format('2. P(booking_success=yes | high_demand=yes) = ~6f~n', [P2]),
    format('3. P(config_error=yes | booking_success=no) = ~6f~n', [P3]),
    format('4. P(config_error=yes | help_request=yes) = ~6f~n', [P4]),
    format('5. P(booking_success=yes | rooms_available=no) = ~6f~n', [P5]).
