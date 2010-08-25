--
-- PostgreSQL database dump
--

-- Started on 2010-08-23 15:36:27 CEST

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

--
-- TOC entry 1984 (class 0 OID 0)
-- Dependencies: 1617
-- Name: basickey_bk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('basickey_bk_id_seq', 1, false);


--
-- TOC entry 1985 (class 0 OID 0)
-- Dependencies: 1620
-- Name: dataset_ds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('dataset_ds_id_seq', 9, true);


--
-- TOC entry 1986 (class 0 OID 0)
-- Dependencies: 1626
-- Name: geographicalarea_ga_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('geographicalarea_ga_id_seq', 1, false);


--
-- TOC entry 1987 (class 0 OID 0)
-- Dependencies: 1628
-- Name: hierarchicalkey_hk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('hierarchicalkey_hk_id_seq', 1, false);


--
-- TOC entry 1988 (class 0 OID 0)
-- Dependencies: 1631
-- Name: metadata_md_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('metadata_md_id_seq', 7, true);


--
-- TOC entry 1976 (class 0 OID 19165)
-- Dependencies: 1632
-- Data for Name: metadatatype; Type: TABLE DATA; Schema: public; Owner: admin
--

INSERT INTO metadatatype (mt_name, mt_share, mt_def) VALUES ('title', false, 'A descriptive title for the dataset');
INSERT INTO metadatatype (mt_name, mt_share, mt_def) VALUES ('abstract', false, 'Brief narrative summary for the dataset');
INSERT INTO metadatatype (mt_name, mt_share, mt_def) VALUES ('dataref', false, 'URL reference to data, or short name');

--
-- TOC entry 1975 (class 0 OID 19157)
-- Dependencies: 1630
-- Data for Name: metadata; Type: TABLE DATA; Schema: public; Owner: admin
--

INSERT INTO metadata (md_id, mt_name, md_content, md_content_vector) VALUES (2, 'title', 'Title 1', NULL);
INSERT INTO metadata (md_id, mt_name, md_content, md_content_vector) VALUES (3, 'abstract', 'Abstract 1', NULL);
INSERT INTO metadata (md_id, mt_name, md_content, md_content_vector) VALUES (6, 'abstract', 'Abstract 2', NULL);
INSERT INTO metadata (md_id, mt_name, md_content, md_content_vector) VALUES (7, 'dataref', 'http://example.com/somefile2', NULL);
INSERT INTO metadata (md_id, mt_name, md_content, md_content_vector) VALUES (4, 'dataref', 'http://example.com/somefile1', NULL);
INSERT INTO metadata (md_id, mt_name, md_content, md_content_vector) VALUES (5, 'title', 'Title 2', NULL);

--
-- TOC entry 1967 (class 0 OID 19115)
-- Dependencies: 1619
-- Data for Name: dataset; Type: TABLE DATA; Schema: public; Owner: admin
--

INSERT INTO dataset (ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationdate, ds_metadataformat, ds_filepath) VALUES (1, 'DAMOC/DTU', 0, 1, '2010-01-01 00:00:00', 'DAM', '2010-01-01 00:00:00', 'MM2', NULL);
INSERT INTO dataset (ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationdate, ds_metadataformat, ds_filepath) VALUES (2, 'DAMOC/AWI_1', 0, 1, '2010-01-01 00:00:00', 'DAM', '2010-01-01 00:00:00', 'MM2', NULL);
INSERT INTO dataset (ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationdate, ds_metadataformat, ds_filepath) VALUES (8, 'DAMOC/itp04/itp04_itp4grd0530', 3, 1, '2010-01-01 00:00:00', 'DAM', '2010-01-01 00:00:00', 'MM2', NULL);
INSERT INTO dataset (ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationdate, ds_metadataformat, ds_filepath) VALUES (3, 'DAMOC/itp04', 0, 1, '2010-01-01 00:00:00', 'DAM', '2010-01-01 00:00:00', 'MM2', NULL);
INSERT INTO dataset (ds_id, ds_name, ds_parent, ds_status, ds_datestamp, ds_ownertag, ds_creationdate, ds_metadataformat, ds_filepath) VALUES (9, 'DAMOC/itp04/itp04_itp4grd0351', 3, 1, '2010-01-01 00:00:00', 'DAM', '2010-01-01 00:00:00', 'MM2', NULL);

--
-- TOC entry 1969 (class 0 OID 19126)
-- Dependencies: 1622
-- Data for Name: ds_has_md; Type: TABLE DATA; Schema: public; Owner: admin
--

INSERT INTO ds_has_md (ds_id, md_id) VALUES (8, 2);
INSERT INTO ds_has_md (ds_id, md_id) VALUES (8, 3);
INSERT INTO ds_has_md (ds_id, md_id) VALUES (8, 4);
INSERT INTO ds_has_md (ds_id, md_id) VALUES (9, 5);
INSERT INTO ds_has_md (ds_id, md_id) VALUES (9, 6);
INSERT INTO ds_has_md (ds_id, md_id) VALUES (9, 7);
