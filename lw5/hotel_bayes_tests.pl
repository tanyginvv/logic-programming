:- encoding(utf8).
:- use_module(hotel_bayes).
:- begin_tests(hotel_bayes).

close_to(Actual, Expected) :- assertion(abs(Actual-Expected) < 1.0e-9).

% Ожидаемые значения получены аналитически, независимо от перебора.
test(booking_prior) :-
    marginal(booking_success-yes, P), close_to(P, 0.575025).
test(booking_in_high_demand) :-
    posterior(booking_success, yes, [high_demand-yes], P), close_to(P, 0.30668).
test(error_after_failed_booking) :-
    posterior(config_error, yes, [booking_success-no], P),
    close_to(P, 0.2053061944820284).
test(error_after_help_request) :-
    posterior(config_error, yes, [help_request-yes], P),
    close_to(P, 0.18674913762340908).
test(no_rooms_no_booking) :-
    posterior(booking_success, yes, [rooms_available-no], P), close_to(P, 0.0).
test(conjunction) :-
    probability([booking_success-yes, help_request-yes], [], P),
    close_to(P, 0.02875125).
test(complement) :-
    posterior(config_error, yes, [help_request-yes], Yes),
    posterior(config_error, no, [help_request-yes], No), close_to(Yes+No, 1.0).
test(observed_event) :-
    posterior(rate_visible, yes, [rate_visible-yes], P), close_to(P, 1.0).
test(contradicted_event) :-
    posterior(rate_visible, yes, [rate_visible-no], P), close_to(P, 0.0).
test(empty_query) :- probability([], [config_error-yes], P), close_to(P, 1.0).
test(normalization_and_world_count) :-
    findall(P, (hotel_bayes:world(W), joint(W,P)), Ps),
    length(Ps,64), sum_list(Ps,Total), close_to(Total,1.0).
test(cpt_complete_unique_and_valid) :-
    forall(parents(V,Parents),
           (length(Parents,N), length(States,N),
            forall(maplist(hotel_bayes:state,States),
                   (findall(P,cpt(V,States,P),[Only]),
                    assertion(Only >= 0.0), assertion(Only =< 1.0))))).
test(impossible_evidence, [throws(error(impossible_evidence(_),_))]) :-
    probability([], [rooms_available-no,booking_success-yes], _).
test(duplicate_evidence, [throws(error(duplicate_variables,_))]) :-
    probability([], [config_error-yes,config_error-no], _).
test(unknown_variable, [throws(error(invalid_assignment(_),_))]) :-
    probability([typo-yes], [], _).
test(unknown_value, [throws(error(invalid_assignment(_),_))]) :-
    probability([config_error-unknown], [], _).
test(unbound_input, [throws(error(invalid_assignments(_),_))]) :-
    probability([config_error-_], [], _).

:- end_tests(hotel_bayes).
