-- Dropping the transactional subscriptions
use [CustomWorks]
exec sp_dropsubscription @publication = N'WestProd', @subscriber = N'DESKTOP-OVN2GNF', @destination_db = N'CustomWorksRep', @article = N'all'

-- Dropping the transactional articles
use [CustomWorks]
exec sp_dropsubscription @publication = N'WestProd', @article = N'Accounts', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'Accounts', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'accounts_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'accounts_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'area_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'area_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'catery_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'catery_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'entity_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'entity_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'estimate_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'estimate_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'faq_catery_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'faq_catery_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'faq_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'faq_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'inventory_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'inventory_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'location_import', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'location_import', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'locations_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'locations_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'marketreq_tbl2', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'marketreq_tbl2', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'mpbid_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'mpbid_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'orderitems_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'orderitems_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'orders_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'orders_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'pdfs_addon_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'pdfs_addon_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'pdfs_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'pdfs_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'recurring_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'recurring_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'regionmaster_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'regionmaster_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'regions_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'regions_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'responses_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'responses_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'rfq_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'rfq_tbl', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'sysdiagrams', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'sysdiagrams', @force_invalidate_snapshot = 1
exec sp_dropsubscription @publication = N'WestProd', @article = N'trackingnumber_tbl', @subscriber = N'all', @destination_db = N'all'
exec sp_droparticle @publication = N'WestProd', @article = N'trackingnumber_tbl', @force_invalidate_snapshot = 1

-- Dropping the transactional publication
use [CustomWorks]
exec sp_droppublication @publication = N'WestProd'
