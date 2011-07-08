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

SELECT pg_catalog.setval('dataset_ds_id_seq', 2, true);


--
-- TOC entry 1783 (class 0 OID 0)
-- Dependencies: 1483
-- Name: infods_i_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('infods_i_id_seq', 4, false);


--
-- TOC entry 1784 (class 0 OID 0)
-- Dependencies: 1485
-- Name: infouds_i_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('infouds_i_id_seq', 1, true);


--
-- TOC entry 1785 (class 0 OID 0)
-- Dependencies: 1479
-- Name: usertable_u_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('usertable_u_id_seq', 2, true);


--
-- TOC entry 1775 (class 0 OID 19438)
-- Dependencies: 1480
-- Data for Name: usertable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY usertable (u_id, a_id, u_name, u_loginname, u_email, u_password, u_institution, u_telephone) FROM stdin;
1	EXAMPLE	tester	metamod1	metamod@met.no	\N	met.no	\N
\.

--
-- TOC entry 1776 (class 0 OID 19449)
-- Dependencies: 1482
-- Data for Name: dataset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dataset (ds_id, u_id, a_id, ds_name) FROM stdin;
1	1	EXAMPLE	hirlam12
\.


--
-- TOC entry 1777 (class 0 OID 19467)
-- Dependencies: 1484
-- Data for Name: infods; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY infods (i_id, ds_id, i_type, i_content) FROM stdin;
1	1	DSKEY	test
2	1	CATALOG	test
3	1	LOCATION	test
\.

