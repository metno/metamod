--
-- PostgreSQL database dump
--

-- Started on 2010-09-07 14:59:17 CEST

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

--
-- TOC entry 1782 (class 0 OID 0)
-- Dependencies: 1481
-- Name: dataset_ds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dataset_ds_id_seq', 7, true);


--
-- TOC entry 1783 (class 0 OID 0)
-- Dependencies: 1483
-- Name: infods_i_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('infods_i_id_seq', 3, true);


--
-- TOC entry 1784 (class 0 OID 0)
-- Dependencies: 1485
-- Name: infouds_i_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('infouds_i_id_seq', 1, false);


--
-- TOC entry 1785 (class 0 OID 0)
-- Dependencies: 1479
-- Name: usertable_u_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('usertable_u_id_seq', 1, true);

--
-- TOC entry 1775 (class 0 OID 19438)
-- Dependencies: 1480
-- Data for Name: usertable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY usertable (u_id, a_id, u_name, u_loginname, u_email, u_password, u_institution, u_telephone) FROM stdin;
1	TEST	tester	metamod	metamod@met.no	\N	\N	\N
\.

--
-- TOC entry 1776 (class 0 OID 19449)
-- Dependencies: 1482
-- Data for Name: dataset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dataset (ds_id, u_id, a_id, ds_name) FROM stdin;
1	1	TEST	itp03
4	1	TEST	itp04
5	1	TEST	itp05
6	1	TEST	itp07
7	1	TEST	itp02
\.

