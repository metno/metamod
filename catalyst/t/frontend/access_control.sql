--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

--
-- Name: usertable_u_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('usertable_u_id_seq', 2, true);


--
-- Data for Name: usertable; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY usertable (u_id, a_id, u_name, u_email, u_loginname, u_password, u_institution, u_telephone, u_session) FROM stdin;
1	metamod-test	Test user	test@example.com	test	a94a8fe5ccb19ba61c4c0873d391e987982fbbd3	ASI	4324324234	\N
\.

