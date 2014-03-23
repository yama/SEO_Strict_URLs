//<?php
/**
 * SEO Strict URLs
 *
 * Enforces the use of strict URLs to prevent duplicate content.
 *
 * @category	plugin
 * @version		1.0.5
 * @license		http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @author		Jeremy Luebke, Phize
 * @internal	@properties &editDocLinks=Edit document links;int;1 &makeFolders=Rewrite containers as folders;int;1 &emptyFolders=Check for empty container	when rewriting;int;1 &override=Enable manual overrides;int;0 &overrideTV=Override TV name;string;seoOverride;
 * @internal	@events OnWebPageInit,OnWebPagePrerender
 * @internal	@modx_category Manager and Admin
 */

// Strict URLs
// version 1.0.4
// Enforces the use of strict URLs to prevent duplicate content.
// By Jeremy Luebke @ www.xuru.com
// Contributions by Brian Stanback @ www.stanback.net

// On Install: Check the "OnWebPageInit" & "OnWebPagePrerender" boxes in the System Events tab.
// Plugin configuration: &editDocLinks=Edit document links;int;1 &makeFolders=Rewrite containers as folders;int;1 &emptyFolders=Check for empty container when rewriting;int;0 &override=Enable manual overrides;int;0 &overrideTV=Override TV name;string;seoOverride

// For overriding documents, create a new template variabe (TV) named seoOverride with the following options:
//    Input Type: DropDown List Menu
//    Input Option Values: Disabled==-1||Base Name==0||Append Extension==1||Folder==2
//    Default Value: -1

//  # Include the following in your .htaccess file
//  # Replace "example.com" &  "example\.com" with your domain info
//  RewriteCond %{HTTP_HOST} .
//  RewriteCond %{HTTP_HOST} !^www\.example\.com [NC]
//  RewriteRule (.*) http://www.example.com/$1 [R=301,L] 

// Some codes are added/modified by Phize(http://phize.net)

// Begin plugin code
$tbl_site_content               = $modx->getFullTableName('site_content');
$tbl_site_tmplvar_contentvalues = $modx->getFullTableName('site_tmplvar_contentvalues');
$tbl_site_tmplvar_templates     = $modx->getFullTableName('site_tmplvar_templates');
$tbl_site_tmplvars              = $modx->getFullTableName('site_tmplvars');

if ($modx->event->name === 'OnWebPageInit')
{
	if(!isset($modx->documentIdentifier)||empty($modx->documentIdentifier)) return;
	
	$docid = $modx->documentIdentifier;
	
	$parts = explode('?', $_SERVER['REQUEST_URI']);
	
	// Added by Phize
	preg_match('#^.+?(?<!\?)&(.*?)(?:\?.*)?$#', $_SERVER['REQUEST_URI'], $matches);
	$parameters = $matches[1];
	//
	
	if ($makeFolders)
	{
		if ($emptyFolders)
		{
			$result = $modx->db->select('isfolder', $tbl_site_content, "id='{$docid}'");
			$isfolder = $modx->db->getValue($result);
		}
		else
		{
			$isfolder = (count($modx->getChildIds($docid, 1)) > 0) ? 1 : 0;
		}
	}
	
	if ($override && $overrideOption = $modx->getTemplateVarOutput($overrideTV, $docid))
	{
		switch ($overrideOption[$overrideTV])
		{
			case 0:
				$isoverride = 1;
				break;
			case 1:
				$isfolder = 0;
				break;
			case 2:
				$makeFolders = 1;
				$isfolder = 1;
		}
	}
	
	if (method_exists($modx, 'setAliasListing')) $modx->setAliasListing();
	$alias = $modx->aliasListing[$docid]['alias'];
	$relurl = $modx->makeUrl($docid,'','','full');
	if ($isoverride)                   $strictURL = preg_replace('@[^/]+$@', $alias, $relurl);
	elseif ($isfolder && $makeFolders && substr($relurl,-1)!=='/')
	                                   $strictURL = preg_replace('@[^/]+$@', $alias, $relurl) . '/';
	else                               $strictURL = $relurl;
	
	$myProtocol = ($_SERVER['HTTPS'] == 'on') ? 'https' : 'http';
	$myDomain = $myProtocol . '://' . $_SERVER['HTTP_HOST'];
	$requestedURL = $myDomain . $parts[0];
	
	if ($docid == $modx->config['site_start'])
	{
		$site_url = $modx->config['site_url'];
		if($requestedURL != $site_url)
		{
			// Force redirect of site start
			$qstring = preg_replace("#(^|&)(q|id)=[^&]+#", '', $parts[1]);  // Strip conflicting id/q from query string
			
			// Modified by Phize
			if ($qstring && $parameters) $url = "{$site_url}?{$qstring}&{$parameters}";
			elseif($qstring)             $url = "{$site_url}?{$qstring}";
			elseif($parameters)          $url = "{$site_url}?{$parameters}";
			else                         $url = $site_url;
		}
	}
	elseif ($parts[0] != $strictURL)
	{
		// Force page redirect
		$qstring = preg_replace("#(^|&)(q|id)=[^&]+#", '', $parts[1]);  // Strip conflicting id/q from query string
		
		// Modified by Phize
		if ($qstring && $parameters) $url = "{$strictURL}?{$qstring}&{$parameters}";
		elseif($qstring)             $url = "{$strictURL}?{$qstring}";
		elseif($parameters)          $url = "{$strictURL}?{$parameters}";
		else                         $url = $strictURL;
		
	}
	
	if(isset($url)&&$requestedURL!==$url)
	{
		header("HTTP/1.1 301 Moved Permanently");
		header("Location: {$url}");
		exit(0);
	}
}
elseif ($modx->event->name === 'OnWebPagePrerender')
{
	if (!$editDocLinks) return;
	
	$myDomain = $_SERVER['HTTP_HOST'];
	$furlSuffix = $modx->config['friendly_url_suffix'];
	$baseUrl = $modx->config['base_url'];
	$o = &$modx->documentOutput; // get a reference of the output
	
	// Reduce site start to base url
	if (method_exists($modx, 'setAliasListing')) $modx->setAliasListing();
	if(!is_array($modx->aliasListing)) return;
	
	$overrideAlias = $modx->aliasListing[$modx->config['site_start']]['alias'];
	$overridePath = $modx->aliasListing[$modx->config['site_start']]['path'];
	// Modified by Phize
	$o = preg_replace("#((href|action)=\"|$myDomain)($baseUrl)?($overridePath/)?$overrideAlias$furlSuffix([^\w-\.!~\*\(\)])#", '${1}' . $baseUrl . '${5}', $o);
	
	if ($override)
	{
		// Replace manual override links
		$sql = "SELECT tvc.contentid as id, tvc.value as value FROM " . $tbl_site_tmplvars . " tv ";
		$sql .= "INNER JOIN " . $tbl_site_tmplvar_templates . " tvtpl ON tvtpl.tmplvarid = tv.id ";
		$sql .= "LEFT JOIN " . $tbl_site_tmplvar_contentvalues . " tvc ON tvc.tmplvarid = tv.id ";
		$sql .= "LEFT JOIN " . $tbl_site_content . " sc ON sc.id = tvc.contentid ";
		$sql .= "WHERE sc.published = 1 AND tvtpl.templateid = sc.template AND tv.name = '{$overrideTV}'";
		$results = $modx->db->query($sql);
		while ($row = $modx->db->getRow($results))
		{
			$overrideAlias = $modx->aliasListing[$row['id']]['alias'];
			$overridePath = $modx->aliasListing[$row['id']]['path'];
			switch ($row['value'])
			{
				case 0:
					// Modified by Phize
					$o = preg_replace("#((href|action)=[\"']($baseUrl)?($overridePath/)?|$myDomain$baseUrl$overridePath/?)$overrideAlias$furlSuffix([^\w-\.!~\*\(\)])#", '${1}' . $overrideAlias . '${5}', $o);
					break;
				case 2:
					// Modified by Phize
					$o = preg_replace("#((href|action)=[\"']($baseUrl)?($overridePath/)?|$myDomain$baseUrl$overridePath/?)$overrideAlias$furlSuffix(/|([^\w-\.!~\*\(\)]))#", '${1}' . rtrim($overrideAlias, '/') . '/' . '${6}', $o);
					break;
			}
		}
	}
	
	if ($makeFolders)
	{
		if ($emptyFolders)
		{
			// Populate isfolder array
			$isfolder_arr = array();
			$result = $modx->db->select('id', $tbl_site_content, 'published > 0 AND isfolder > 0');
			while ($row = $modx->db->getRow($result))
			{
				$isfolder_arr[$row['id']] = true;
			}
		}
		
		// Replace container links
		foreach ($modx->aliasListing as $v)
		{
			$id = $v['id'];
			if ((is_array($isfolder_arr) && isset($isfolder_arr[$id])) || count($modx->getChildIds($id, 1)))
			{
				$overrideAlias = $modx->aliasListing[$id]['alias'];
				$overridePath = $modx->aliasListing[$id]['path'];
				// Modified by Phize
				$o = preg_replace("#((href|action)=[\"']($baseUrl)?($overridePath/)?|$myDomain$baseUrl$overridePath/?)$overrideAlias$furlSuffix(/|([^\w-\.!~\*\(\)]))#", '${1}' . rtrim($overrideAlias, '/') . '/' . '${6}', $o);
			}
		}
	}
}
else return;
