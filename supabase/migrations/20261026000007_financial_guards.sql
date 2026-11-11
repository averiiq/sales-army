BEGIN;
CREATE FUNCTION public.protect_shop_balance() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$ BEGIN
  IF current_user='authenticated' THEN
    IF TG_OP='INSERT' AND COALESCE(NEW.current_outstanding,0)<>0 THEN RAISE EXCEPTION 'Opening balances require a ledger transaction'; END IF;
    IF TG_OP='UPDATE' AND NEW.current_outstanding IS DISTINCT FROM OLD.current_outstanding THEN RAISE EXCEPTION 'Balance changes require a ledger transaction'; END IF;
    IF TG_OP='DELETE' AND (OLD.current_outstanding<>0 OR EXISTS(SELECT 1 FROM public.invoices WHERE tenant_id=OLD.tenant_id AND shop_id=OLD.shop_id)) THEN RAISE EXCEPTION 'A shop with financial history cannot be deleted'; END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER protect_shop_balance BEFORE INSERT OR UPDATE OR DELETE ON public.shops FOR EACH ROW EXECUTE FUNCTION public.protect_shop_balance();

UPDATE public.platform_settings SET data=data-'passcode'-'adminPasscode'-'password'-'keySecret'-'webhookSecret';
CREATE FUNCTION public.protect_setting_secrets() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN
  IF NEW.data::text ~* '"(keySecret|webhookSecret|passcode|adminPasscode|password)"[[:space:]]*:' THEN
    RAISE EXCEPTION 'Credentials belong in server environment configuration';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER protect_setting_secrets BEFORE INSERT OR UPDATE ON public.platform_settings FOR EACH ROW EXECUTE FUNCTION public.protect_setting_secrets();
CREATE POLICY public_gateway_metadata ON public.platform_settings FOR SELECT TO authenticated USING(id IN ('paymentGateway','company'));
COMMIT;
