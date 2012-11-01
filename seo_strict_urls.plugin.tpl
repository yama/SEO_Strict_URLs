//<?php
/**
 * SEO Strict URLs
 *
 * Enforces the use of strict URLs to prevent duplicate content.
 *
 * @category	plugin
 * @version		1.0.1P3
 * @license		http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @author		Jeremy Luebke, Phize
 * @internal	@properties &editDocLinks=Edit document links;int;1 &makeFolders=Rewrite containers as folders;int;1 &emptyFolders=Check for empty container	when rewriting;int;1 &override=Enable manual overrides;int;0 &overrideTV=Override TV name;string;seoOverride;
 * @internal	@events OnWebPageInit,OnWebPagePrerender
 * @internal	@modx_category Manager and Admin
 */

// Strict URLs
// version 1.0.1
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

$tbl_site_tmplvar_templates     = $modx->getFullTableName('site_tmplvar_templates');
$tbl_site_tmplvar_contentvalues = $modx->getFullTableName('site_tmplvar_contentvalues');
$tbl_site_tmplvars              = $modx->getFullTableName('site_tmplvars');
$tbl_site_content               = $modx->getFullTableName('site_content');

$e = &$modx->event;
if ($e->name == 'OnWebPageInit')
{
   $documentIdentifier = $modx->documentIdentifier;

   if ($documentIdentifier)  // Check for 404 error
   {
      $myProtocol = ($_SERVER['HTTPS'] == 'on') ? 'https' : 'http';
      $s = $_SERVER['REQUEST_URI'];
      $parts = explode("?", $s);

      // Added by Phize
      preg_match('#^.+?(?<!\?)&(.*?)(?:\?.*)?$#', $s, $matches);
      $parameters = $matches[1];
      //

      if (method_exists($modx, 'setAliasListing')) $modx->setAliasListing();
      $alias = $modx->aliasListing[$documentIdentifier]['alias'];
      if ($makeFolders)
      {
         if ($emptyFolders)
         {
            $result = $modx->db->select('isfolder', $tbl_site_content, "id='{$documentIdentifier}'");
            $isfolder = $modx->db->getValue($result);
         }
         else
         {
            $isfolder = (count($modx->getChildIds($documentIdentifier, 1)) > 0) ? 1 : 0;
         }
      }

      if ($override && $overrideOption = $modx->getTemplateVarOutput($overrideTV, $documentIdentifier))
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

      if ($isoverride)
      {
         $strictURL = preg_replace('/[^\/]+$/', $alias, $modx->makeUrl($documentIdentifier));
      }
      elseif ($isfolder && $makeFolders)
      {
         $strictURL = preg_replace('/[^\/]+$/', $alias, $modx->makeUrl($documentIdentifier)) . "/";
      }
      else
      {
         $strictURL = $modx->makeUrl($documentIdentifier);
      }

      // Added by Phize
      //if ($parameters) {
      //    $strictURL .= '&' . $parameters;
      //}

      $myDomain = $myProtocol . "://" . $_SERVER['HTTP_HOST'];
      $newURL = $myDomain . $strictURL;
      $requestedURL = $myDomain . $parts[0];

      if ($documentIdentifier == $modx->config['site_start'])
      {
         if ($requestedURL != $modx->config['site_url'])
         {
            // Force redirect of site start
            header("HTTP/1.1 301 Moved Permanently");
            $qstring = preg_replace("#(^|&)(q|id)=[^&]+#", '', $parts[1]);  // Strip conflicting id/q from query string

            // Modified by Phize
            $site_url = $modx->config['site_url'];
            if($qstring && $parameters) $dist = "{$site_url}?{$qstring}&{$parameters}";
            elseif($qstring)            $dist = "{$site_url}?{$qstring}";
            elseif($parameters)         $dist = "{$site_url}?{$parameters}";
            else                        $dist = $site_url;
            header("Location: {$dist}");
            exit(0);
         }
      }
      elseif ($parts[0] != $strictURL)
      {
         // Force page redirect
         header("HTTP/1.1 301 Moved Permanently");
         $qstring = preg_replace("#(^|&)(q|id)=[^&]+#", '', $parts[1]);  // Strip conflicting id/q from query string

         // Modified by Phize
         if($qstring && $parameters) $dist = "{$strictURL}?{$qstring}&{$parameters}";
         elseif($qstring)            $dist = "{$strictURL}?{$qstring}";
         elseif($parameters)         $dist = "{$strictURL}?{$parameters}";
         else                        $dist = $strictURL;
         header("Location: {$dist}");
         exit(0);
      }
   }
}
elseif ($e->name == 'OnWebPagePrerender')
{
   if ($editDocLinks)
   {
      $myDomain = $_SERVER['HTTP_HOST'];
      $furlSuffix = $modx->config['friendly_url_suffix'];
      $baseUrl = $modx->config['base_url'];
      $o = &$modx->documentOutput; // get a reference of the output

      // Reduce site start to base url
      $overrideAlias = $modx->aliasListing[$modx->config['site_start']]['alias'];
      $overridePath = $modx->aliasListing[$modx->config['site_start']]['path'];
      // Modified by Phize
      $o = preg_replace("#((href|action)=\"|$myDomain)($baseUrl)?($overridePath/)?$overrideAlias$furlSuffix([^\w-\.!~\*\(\)])#", '${1}' . $baseUrl . '${5}', $o);

      if ($override)
      {
         // Replace manual override links
         $overrideTV = $modx->db->escape($overrideTV);
         $f = "tvc.contentid as id, tvc.value as value";
         $from  = "{$tbl_site_tmplvars} tv";
         $from .= " INNER JOIN {$tbl_site_tmplvar_templates} tvtpl ON tvtpl.tmplvarid = tv.id ";
         $from .= " LEFT JOIN {$tbl_site_tmplvar_contentvalues} tvc ON tvc.tmplvarid = tv.id ";
         $from .= " LEFT JOIN {$tbl_site_content} sc ON sc.id = tvc.contentid ";
         $where .= "sc.published = 1 AND tvtpl.templateid = sc.template AND tv.name = '{$overrideTV}'";
         $rs = $modx->db->select($f,$from,$where);
         while ($row = $modx->db->getRow($rs))
         {
            $overrideAlias = $modx->aliasListing[$row['id']]['alias'];
            $overridePath  = $modx->aliasListing[$row['id']]['path'];
            $path = "{$myDomain}{$baseUrl}{$overridePath}";
            $page = "{$overrideAlias}{$furlSuffix}";
            switch ($row['value'])
            {
               case 0:
                  // Modified by Phize
                  $o = preg_replace("#((href|action)=[\"']($baseUrl)?($overridePath/)?|$path/?)$page([^\w-\.!~\*\(\)])#", '${1}' . $overrideAlias . '${5}', $o);
                  break;
               case 2:
                  // Modified by Phize
                  $o = preg_replace("#((href|action)=[\"']($baseUrl)?($overridePath/)?|$path/?)$page(/|([^\w-\.!~\*\(\)]))#", '${1}' . rtrim($overrideAlias, '/') . '/' . '${6}', $o);
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
               $isfolder_arr[$row['id']] = true;
         }

         // Replace container links
         foreach ($modx->aliasListing as $v)
         {
            $id = $v['id'];
            if ((is_array($isfolder_arr) && isset($isfolder_arr[$id])) || count($modx->getChildIds($id, 1)))
            {
               $overrideAlias = $modx->aliasListing[$id]['alias'];
               $overridePath  = $modx->aliasListing[$id]['path'];
               // Modified by Phize
               $path = "{$myDomain}{$baseUrl}{$overridePath}";
               $page = "{$overrideAlias}{$furlSuffix}";
               $o = preg_replace("#((href|action)=[\"']($baseUrl)?($overridePath/)?|$path/?)$page(/|([^\w-\.!~\*\(\)]))#", '${1}' . rtrim($overrideAlias, '/') . '/' . '${6}', $o);
            }
         }
      }
   }
}
else return;
